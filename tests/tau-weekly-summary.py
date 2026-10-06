import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
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
            self.assertEqual(weekly.timestamp(end), f"{date}T00:00:00Z")
            self.assertEqual((end - start).total_seconds(), 7 * 86400)

    def test_windows(self):
        for now, expected in [
            ("2026-10-05T09:00:00+00:00", "2026-10-05T00:00:00Z"),
            ("2026-10-11T23:59:59+00:00", "2026-10-05T00:00:00Z"),
            ("2026-10-12T00:00:00+00:00", "2026-10-12T00:00:00Z"),
            ("2026-01-01T09:00:00+00:00", "2025-12-29T00:00:00Z"),
            ("2026-10-05T01:00:00+02:00", "2026-09-28T00:00:00Z"),
        ]:
            start, end = weekly.reporting_window(datetime.fromisoformat(now))
            self.assertEqual(weekly.timestamp(end), expected)
            self.assertEqual((end - start).total_seconds(), 7 * 86400)

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
                     "--window-end", "2026-10-05T00:00:00Z"],
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
            self.assertIn("fedimint-weekly-20261005T000000Z", message)
            self.assertIn("2026-09-28T00:00:00Z <= activity time < 2026-10-05T00:00:00Z", message)

    def test_bad_window_never_sends(self):
        for end in ("bad", "2026-10-06T00:00:00Z", "2026-10-05T09:00:00Z"):
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "/nonexistent-tau",
                 "--window-end", end], capture_output=True,
            )
            self.assertEqual(result.returncode, 2)


unittest.main()
