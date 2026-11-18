import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from datetime import datetime


SCRIPT = Path(sys.argv.pop(1))
spec = importlib.util.spec_from_file_location("weekly", SCRIPT)
weekly = importlib.util.module_from_spec(spec)
spec.loader.exec_module(weekly)


class WeeklySummaryTests(unittest.TestCase):
    def test_new_invocation_uses_current_window(self):
        now = datetime.fromisoformat("2026-10-06T00:36:23.987654+00:00")
        with patch.object(weekly, "datetime") as clock, \
                patch.object(weekly.subprocess, "run") as send, \
                patch.object(sys, "argv", [str(SCRIPT), "/fake-tau"]):
            clock.now.return_value = now
            send.return_value.returncode = 0
            self.assertEqual(weekly.main(), 0)
            send.assert_called_once()
            message = send.call_args.kwargs["input"]
            self.assertIn("use the fedimint-bot-weekly-dev-summary skill", message)
            self.assertIn(
                "2026-09-28T08:36:23Z <= activity time < 2026-10-06T00:36:23Z",
                message,
            )
            self.assertIn("fedimint-weekly-20261006T003623", message)
            self.assertNotIn("discord_send", message)

    def test_single_send_and_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            fake = Path(directory) / "tau"
            capture = Path(directory) / "capture"
            for repo_args, repo, channel, prefix in (
                ([], "fedimint/fedimint", "general", "fedimint-weekly"),
                (["--repo", "fedimint/fedimint-sdk"], "fedimint/fedimint-sdk", "sdk", "fedimint-sdk-weekly"),
            ):
                with self.subTest(repo=repo):
                    capture.unlink(missing_ok=True)
                    for status in (0, 42):
                        fake.write_text(
                            f"#!{sys.executable}\n"
                            "import sys, json\n"
                            f"with open({str(capture)!r}, 'a') as output:\n"
                            "    output.write(json.dumps([sys.argv[1:], sys.stdin.read()]) + '\\n')\n"
                            f"sys.exit({status})\n"
                        )
                        fake.chmod(0o700)
                        result = subprocess.run(
                            [sys.executable, str(SCRIPT), str(fake), *repo_args,
                             "--window-end", "2026-10-06T00:36:23Z",
                             "--announce-channel", channel],
                            capture_output=True, text=True,
                        )
                        self.assertEqual(result.returncode, status)
                        self.assertEqual("Delivery acknowledged" in result.stdout, status == 0)
                    sends = [json.loads(line) for line in capture.read_text().splitlines()]
                    self.assertEqual(len(sends), 2)
                    self.assertEqual(sends[0], sends[1])
                    arguments, message = sends[0]
                    self.assertEqual(arguments, ["message", "&tau-fedimint-bot"])
                    self.assertIn(f"Repository argument: {repo}.", message)
                    self.assertIn(f"publish to https://github.com/{repo}/wiki.", message)
                    self.assertIn(f"Occurrence ID: {prefix}-20261006T003623Z.", message)
                    self.assertIn("2026-09-28T08:36:23Z <= activity time < 2026-10-06T00:36:23Z", message)
                    self.assertIn("Week-summary-5-October,-2026.md", message)
                    self.assertIn(f"discord_send to {channel} as a plain link without mentions", message)

    def test_invalid_arguments_never_send(self):
        for args in (
            ("--window-end", "bad"),
            ("--window-end", "2026-10-06"),
            ("--window-end", "2026-10-05T09:00:00+01:00"),
            ("--repo", "fedimint/fedimint-observer"),
            ("--repo", "fedimint/fedimint-sdk", "--announce-channel", "general"),
            ("--announce-channel", "sdk"),
        ):
            with self.subTest(args=args):
                result = subprocess.run(
                    [sys.executable, str(SCRIPT), "/nonexistent-tau", *args],
                    capture_output=True,
                )
                self.assertEqual(result.returncode, 2)


unittest.main()
