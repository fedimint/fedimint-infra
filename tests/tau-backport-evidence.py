"""Exercise the installed evidence CLI against a fake broker."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

COMMAND = sys.argv.pop(1)
REPO = "fedimint/fedimint"
PR = 9609
RUN = 45922449149
ATTEMPT = 2
HEAD = "a" * 40
MERGE = "b" * 40
JOB = "Notify Discord of failed backports"
STEP = "Send backport failure to Discord"


def run_data(**overrides):
    return {
        "id": RUN,
        "repository": {"full_name": REPO},
        "path": ".github/workflows/backport.yml",
        "event": "pull_request_target",
        "run_attempt": ATTEMPT,
        "head_sha": HEAD,
        "status": "completed",
        "conclusion": "success",
        "pull_requests": [],
        **overrides,
    }


def source_data(**overrides):
    return {
        "number": PR,
        "base": {"ref": "master", "repo": {"full_name": REPO}},
        "head": {"sha": HEAD},
        "merged": True,
        "merge_commit_sha": MERGE,
        "labels": [
            {"name": "backport releases/v0.12"},
            {"name": "backport releases/v0.13"},
        ],
        **overrides,
    }


def log_for(*results, pr=PR, job=JOB, step=STEP):
    lines = [
        "##[group]Run sarisia/actions-status-discord@eb045afee445dc055c18d3d90bd0f244fd062708",
        "with:",
        "  webhook: ***",
        "  status: failure",
        "  title: Backport failed",
        f"  content: Backport failed for {REPO}#{pr} (<https://github.com/{REPO}/pull/{pr}>). "
        f"Run: <https://github.com/{REPO}/actions/runs/{RUN}/attempts/{ATTEMPT}>.",
        "  description: Target results (`false` means the backport failed):",
    ]
    prefix = f"{job}\t{step}\t"
    timestamp = "2026-11-27T01:42:10.0000000Z"
    return f"{prefix}\ufeff{timestamp} {lines[0]}\n" + "".join(
        f"{prefix}{timestamp} {line}\n" for line in lines[1:]
    ) + "".join(f"{prefix}{line}\n" for line in (*results, "")) + (
        f"{prefix}{timestamp}   nodetail: false\n"
        f"{prefix}{timestamp} ##[endgroup]\n"
    )


class EvidenceTest(unittest.TestCase):
    def call(self, log, *, run=None, source=None, args=(PR, RUN, ATTEMPT), deny_log=False):
        with tempfile.TemporaryDirectory() as scratch:
            broker = Path(scratch) / "gh"
            broker.write_text(f"#!{sys.executable}\n" + f"""
import os, sys
args = sys.argv[1:]
if args == ["api", "repos/{REPO}/actions/runs/{RUN}"]:
    print(os.environ["RUN_JSON"])
elif args == ["api", "repos/{REPO}/pulls/{PR}"]:
    print(os.environ["PR_JSON"])
elif args == ["run", "view", "{RUN}", "-R", "{REPO}", "--attempt", "{ATTEMPT}", "--log"]:
    if os.environ["DENIED"]:
        sys.exit("private denied details")
    print(os.environ["LOG"])
else:
    sys.exit("unsupported broker request: " + repr(args))
""")
            broker.chmod(0o755)
            return subprocess.run(
                [COMMAND, *map(str, args)], capture_output=True, text=True, check=False,
                env={
                    **os.environ,
                    "PATH": f"{scratch}:{os.environ['PATH']}",
                    "RUN_JSON": json.dumps(run if run is not None else run_data()),
                    "PR_JSON": json.dumps(source if source is not None else source_data()),
                    "LOG": log,
                    "DENIED": "1" if deny_log else "",
                },
            )

    def test_partial_failure_in_green_run(self):
        result = self.call(log_for("releases/v0.12=false", "releases/v0.13=true"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {
            "source_pull": PR, "merge_commit": MERGE,
            "failed_targets": ["releases/v0.12"], "unlabelled_targets": [],
        })

    def test_removed_label(self):
        result = self.call(
            log_for("releases/v0.12=false", "releases/v0.13=false"),
            source=source_data(labels=[{"name": "backport releases/v0.13"}]),
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["failed_targets"], ["releases/v0.13"])
        self.assertEqual(json.loads(result.stdout)["unlabelled_targets"], ["releases/v0.12"])

    def test_reject_unbound_or_missing_evidence(self):
        failure = "releases/v0.12=false"
        log = log_for(failure)
        for name, candidate, kwargs in [
            ("whole job failure", log_for("Unavailable. See the workflow run for details."),
             {"run": run_data(conclusion="failure")}),
            ("only success", log_for("releases/v0.12=true"), {}),
            ("duplicated result", log_for(failure, failure), {}),
            ("target outside release namespace", log_for("master=false"), {}),
            ("extra timestamped imitation", log_for("2026-11-27T01:42:10Z releases/v0.12=false"), {}),
            ("different PR", log_for(failure, pr=PR + 1), {}),
            ("different workflow", log, {"run": run_data(path=".github/workflows/ci.yml")}),
            ("outdated attempt", log, {"run": run_data(run_attempt=ATTEMPT + 1)}),
            ("different head", log, {"run": run_data(head_sha="c" * 40)}),
            ("unmerged source", log, {"source": source_data(merged=False)}),
            ("untrusted log step", log_for(failure, step="Print arbitrary text"), {}),
            ("log read denied", log, {"deny_log": True}),
            ("argument injection", log, {"args": ("--help", RUN, ATTEMPT)}),
        ]:
            with self.subTest(name):
                result = self.call(candidate, **kwargs)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")
                self.assertNotIn("private denied details", result.stderr)


if __name__ == "__main__":
    unittest.main()
