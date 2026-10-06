import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from datetime import datetime
from zoneinfo import ZoneInfo


SCRIPT = Path(sys.argv.pop(1))
spec = importlib.util.spec_from_file_location("weekly", SCRIPT)
weekly = importlib.util.module_from_spec(spec)
spec.loader.exec_module(weekly)


class WeeklySummaryTests(unittest.TestCase):
    def test_california_schedule_windows(self):
        california = ZoneInfo("America/Los_Angeles")
        for date, expected_hour in [
            ("2026-07-06", 13),  # PDT
            ("2026-12-07", 14),  # PST
            ("2026-03-09", 13),  # first Monday after spring transition
            ("2026-11-02", 14),  # first Monday after fall transition
        ]:
            scheduled = datetime.fromisoformat(f"{date}T06:00:00").replace(
                tzinfo=california
            )
            utc = scheduled.astimezone(weekly.timezone.utc)
            self.assertEqual(utc.hour, expected_hour)
            start, end = weekly.reporting_window(scheduled)
            self.assertEqual(weekly.timestamp(end), f"{date}T{expected_hour}:00:00Z")
            self.assertEqual((end - start).total_seconds(), 184 * 3600)

    def test_windows(self):
        for now, expected in [
            ("2026-10-05T09:00:00+00:00", "2026-10-05T09:00:00Z"),
            ("2026-10-11T23:59:59+00:00", "2026-10-11T23:59:59Z"),
            ("2026-10-12T00:00:00+00:00", "2026-10-12T00:00:00Z"),
            ("2026-01-01T09:00:00+00:00", "2026-01-01T09:00:00Z"),
            ("2026-10-05T01:00:00+02:00", "2026-10-04T23:00:00Z"),
            ("2026-10-06T00:36:23.987654+00:00", "2026-10-06T00:36:23Z"),
        ]:
            start, end = weekly.reporting_window(datetime.fromisoformat(now))
            self.assertEqual(weekly.timestamp(end), expected)
            self.assertEqual((end - start).total_seconds(), 184 * 3600)

    def test_new_invocation_captures_clock_once(self):
        now = datetime.fromisoformat("2026-10-06T00:36:23.987654+00:00")
        with patch.object(weekly, "datetime") as clock, \
                patch.object(weekly.subprocess, "run") as send, \
                patch.object(sys, "argv", [str(SCRIPT), "/fake-tau"]):
            clock.now.return_value = now
            send.return_value.returncode = 0
            self.assertEqual(weekly.main(), 0)
            clock.now.assert_called_once_with(weekly.timezone.utc)
            send.assert_called_once()
            message = send.call_args.kwargs["input"]
            self.assertIn(
                "2026-09-28T08:36:23Z <= activity time < 2026-10-06T00:36:23Z",
                message,
            )
            self.assertIn("fedimint-weekly-20261006T003623", message)

    def test_overlap_across_dst_transitions(self):
        california = ZoneInfo("America/Los_Angeles")
        for first, second, overlap_hours in [
            ("2026-03-02", "2026-03-09", 17),
            ("2026-10-26", "2026-11-02", 15),
        ]:
            first_end = datetime.fromisoformat(f"{first}T06:00:00").replace(
                tzinfo=california
            )
            second_end = datetime.fromisoformat(f"{second}T06:00:00").replace(
                tzinfo=california
            )
            _, prior_end = weekly.reporting_window(first_end)
            start, end = weekly.reporting_window(second_end)
            self.assertEqual((end - start).total_seconds(), 184 * 3600)
            self.assertEqual((prior_end - start).total_seconds(), overlap_hours * 3600)

    def test_page_names_use_california_endpoint_date(self):
        for endpoint, label in [
            ("2026-05-11T13:00:00+00:00", "11 May, 2026"),
            ("2026-10-06T00:36:23+00:00", "5 October, 2026"),
            ("2026-01-01T01:00:00+00:00", "31 December, 2025"),
            ("2026-12-07T14:00:00+00:00", "7 December, 2026"),
        ]:
            start, end = weekly.reporting_window(datetime.fromisoformat(endpoint))
            message = weekly.instruction(start, end)
            self.assertIn(f"# Week summary: {label}", message)
            self.assertIn(f"Week-summary-{label.replace(' ', '-')}.md", message)
            self.assertEqual(message, weekly.instruction(start, end))

    def test_single_send_and_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            fake = Path(directory) / "tau"
            capture = Path(directory) / "capture"
            for status in (0, 1, 42):
                fake.write_text(
                    f"#!{sys.executable}\n"
                    "import sys, json\n"
                    f"with open({str(capture)!r}, 'a') as output:\n"
                    "    output.write(json.dumps([sys.argv[1:], sys.stdin.read()]) + '\\n')\n"
                    f"sys.exit({status})\n"
                )
                fake.chmod(0o700)
                result = subprocess.run(
                    [sys.executable, str(SCRIPT), str(fake),
                     "--window-end", "2026-10-06T00:36:23Z"],
                    capture_output=True, text=True,
                )
                self.assertEqual(result.returncode, status)
                self.assertEqual("Delivery acknowledged" in result.stdout, status == 0)
            sends = [json.loads(line) for line in capture.read_text().splitlines()]
            self.assertEqual(len(sends), 3)
            self.assertEqual(sends[0], sends[1])
            self.assertEqual(sends[1], sends[2])
            arguments, message = sends[0]
            self.assertEqual(arguments, ["message", "&tau-fedimint-bot"])
            self.assertIn("fedimint-weekly-dev-summary", message)
            self.assertIn("fedimint-weekly-20261006T003623Z", message)
            self.assertIn("2026-09-28T08:36:23Z <= activity time < 2026-10-06T00:36:23Z", message)
            self.assertIn("rolling 184-hour lookback", message)
            self.assertIn("do not omit activity because a previous report included it", message)

    def test_bad_window_never_sends(self):
        for end in ("bad", "2026-10-06", "2026-10-05T09:00:00+01:00"):
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "/nonexistent-tau",
                 "--window-end", end], capture_output=True,
            )
            self.assertEqual(result.returncode, 2)


unittest.main()
