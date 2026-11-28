"""Read exact-attempt Fedimint backport evidence through brokered gh."""

import json
import re
import subprocess
import sys
import time

REPO = "fedimint/fedimint"
WORKFLOW = ".github/workflows/backport.yml"
JOB = "Notify Discord of failed backports"
STEP = "Send backport failure to Discord"
ACTION = "sarisia/actions-status-discord@eb045afee445dc055c18d3d90bd0f244fd062708"
DESCRIPTION = "description: Target results (`false` means the backport failed):"
TARGET = r"releases/v[0-9]+\.[0-9]+(?:\.[0-9]+)?"
SHA = r"[0-9a-f]{40}"


class Unverified(ValueError):
    pass


def gh(*args):
    # Never print untrusted logs, PR text or command stderr into the task.
    return subprocess.run(
        ["gh", *args], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        encoding="utf-8", timeout=180,
    ).stdout


def read_run(run, attempt):
    data = json.loads(gh("api", f"repos/{REPO}/actions/runs/{run}"))
    if (
        data["repository"]["full_name"] != REPO
        or data["id"] != run
        or data["run_attempt"] != attempt
        or data["path"] != WORKFLOW
        or data["event"] != "pull_request_target"
    ):
        raise Unverified("not the current Fedimint backport attempt")
    return data


def completed_run(run, attempt):
    # Discord can deliver the alert before Actions has finished uploading logs.
    deadline = time.monotonic() + 120
    while True:
        data = read_run(run, attempt)
        if data["status"] == "completed":
            if data["conclusion"] not in ("success", "failure"):
                raise Unverified("backport attempt did not finish with success or failure")
            return data
        if time.monotonic() >= deadline:
            raise Unverified("backport attempt is still running")
        time.sleep(10)


def failed_targets(log, pr, run, attempt):
    # GitHub's runner logs expanded step inputs, including the upstream target
    # output even when the backport step exits successfully. Do not match free
    # text in other steps, or later output written by the notification action.
    groups = []
    current = None
    for line in log.splitlines():
        parts = line.split("\t", 2)
        if len(parts) != 3 or parts[:2] != [JOB, STEP]:
            continue
        timestamped = re.fullmatch(r"\ufeff?[0-9TZ.:\-]+ (.*)", parts[2])
        text = (timestamped[1] if timestamped else parts[2]).strip()
        if timestamped and text == f"##[group]Run {ACTION}":
            current = []
        elif timestamped and text == "##[endgroup]" and current is not None:
            groups.append(current)
            current = None
        elif current is not None:
            current.append((timestamped is not None, text))

    content = (
        f"content: Backport failed for {REPO}#{pr} "
        f"(<https://github.com/{REPO}/pull/{pr}>). "
        f"Run: <https://github.com/{REPO}/actions/runs/{run}/attempts/{attempt}>."
    )
    if len(groups) != 1 or groups[0].count((True, content)) != 1:
        raise Unverified("notification inputs do not bind the source PR and attempt")
    inputs = groups[0]
    if inputs.count((True, DESCRIPTION)) != 1:
        raise Unverified("no unique per-target result in the notification inputs")
    results = {}
    # The runner timestamps the whole input, not each physical line; gh
    # supplies the job/step columns on continuations without a timestamp.
    for timestamped, line in inputs[inputs.index((True, DESCRIPTION)) + 1:]:
        if timestamped:
            break
        if not line:
            continue
        match = re.fullmatch(rf"({TARGET})=(true|false)", line)
        if not match or match[1] in results:
            raise Unverified("missing, unsupported or ambiguous per-target result")
        results[match[1]] = match[2]
    failed = sorted(target for target, result in results.items() if result == "false")
    if not failed:
        raise Unverified("no independently verified failed release targets")
    return failed


def verify(pr, run, attempt):
    data = completed_run(run, attempt)
    log = gh("run", "view", str(run), "-R", REPO, "--attempt", str(attempt), "--log")
    failed = failed_targets(log, pr, run, attempt)
    source = json.loads(gh("api", f"repos/{REPO}/pulls/{pr}"))
    sha = source["merge_commit_sha"]
    if (
        source["number"] != pr
        or source["merged"] is not True
        or source["base"]["repo"]["full_name"] != REPO
        or source["base"]["ref"] != "master"
        or source["head"]["sha"] != data["head_sha"]
        or not isinstance(sha, str)
        or not re.fullmatch(SHA, sha)
    ):
        raise Unverified("run does not identify a merged Fedimint trunk PR")
    labels = {label["name"] for label in source["labels"]}
    eligible = [target for target in failed if f"backport {target}" in labels]
    read_run(run, attempt)
    return {
        "source_pull": pr,
        "merge_commit": sha,
        "failed_targets": eligible,
        "unlabelled_targets": sorted(set(failed) - set(eligible)),
    }


def main(args):
    if len(args) != 3 or any(not re.fullmatch(r"[1-9][0-9]{0,17}", arg) for arg in args):
        sys.exit("Usage: tau-backport-evidence SOURCE_PR RUN_ID ATTEMPT")
    try:
        print(json.dumps(verify(*map(int, args))))
    except Unverified as exc:
        sys.exit(f"Unverified backport: {exc}")
    except (KeyError, TypeError, ValueError, OSError, subprocess.SubprocessError):
        sys.exit("Unverified backport: GitHub evidence unavailable through brokered gh")


if __name__ == "__main__":
    main(sys.argv[1:])
