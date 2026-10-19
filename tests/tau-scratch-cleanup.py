"""Exercise tmpfiles aging against a live, production-profile isolate.

Run as root in the test VM after the managed profile and SSH socket are ready.
No Tau daemon or external integration is started.
"""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


PROJECT = "/home/tau-fedimint/fedimint"
PAYLOAD = r"""
import json, os, sys, tempfile
from pathlib import Path

def identity(path):
    s = os.stat(path)
    return [s.st_dev, s.st_ino]

mounts = [line.split() for line in open("/proc/self/mountinfo")]
tmp = [m for m in mounts if m[4] == "/tmp"]
assert len(tmp) == 1, tmp
assert any(m[4] == "/tmp/public" for m in mounts)
assert not Path(sys.argv[1]).exists(), "unrelated host /tmp leaked into sandbox"
print(json.dumps({
    "backing": tmp[0][3], "private": identity("/tmp"), "shared": identity("/tmp/public")
}), flush=True)
assert sys.stdin.readline() == "cleaned\n"
if sys.argv[2] == "unprotected":
    assert not Path("/tmp/public").exists(), "negative control did not lose mount"
else:
    assert identity("/tmp/public") == json.loads(sys.argv[3])
    assert any(line.split()[4] == "/tmp/public" for line in open("/proc/self/mountinfo"))
    # tempfile raises on allocation failure: never form an output from an empty path.
    with tempfile.TemporaryDirectory(prefix="scratch-check-", dir="/tmp/public") as d:
        artifact = Path(d) / "artifact"
        artifact.write_text("shared scratch")
        print(str(artifact), flush=True)
        assert sys.stdin.readline() == "observed\n"
"""


def run_case(work, other, rules, protected):
    mode = "protected" if protected else "unprotected"
    outside = work / "host-only"
    outside.touch()
    shared = os.stat("/tmp/public")
    identity = [shared.st_dev, shared.st_ino]
    command = [
        "runuser", "-u", "tau-fedimint", "--", "env",
        "HOME=/home/tau-fedimint", "XDG_RUNTIME_DIR=/run/user/1001",
        "isolate", "-c", PROJECT, "exec", "--profile", "fedimint-bot",
        "--", "python", "-c", PAYLOAD, str(outside), mode, json.dumps(identity),
    ]
    process = subprocess.Popen(
        command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True,
    )
    try:
        ready = json.loads(process.stdout.readline())
        assert ready["shared"] == identity
        # Discover the actual backing from the real isolate, not our Nix hash
        # calculation: an upstream path change must fail this regression.
        root = Path(ready["backing"])
        # mountinfo's root is filesystem-relative: /tmp may itself be a tmpfs.
        assert root.parent in (Path("/"), Path("/tmp")), root
        assert root.name.startswith("isolate-"), root
        backing = Path("/tmp") / root.name
        private = backing.stat()
        assert [private.st_dev, private.st_ino] == ready["private"]
        stale = backing / "scratch-cleanup-stale"
        stale.touch()
        (other / "public").mkdir()
        aging = work / "aging.conf"
        aging.write_text(f"e {backing} - - - 0\ne {other} - - - 0\n")
        cleanup = ["systemd-tmpfiles", "--clean", str(aging)]
        if protected:
            cleanup.append(rules)
        subprocess.run(cleanup, check=True)
        assert not stale.exists(), "ordinary private scratch stopped aging"
        assert not (other / "public").exists(), "unrelated mountpoints protected"
        assert (backing / "public").exists() == protected
        process.stdin.write("cleaned\n")
        process.stdin.flush()
        if protected:
            artifact = Path(process.stdout.readline().strip())
            assert artifact.parent.parent == Path("/tmp/public"), artifact
            assert artifact.read_text() == "shared scratch"
            process.stdin.write("observed\n")
            process.stdin.flush()
        process.stdin.close()
        assert process.wait(timeout=10) == 0, mode
        print(f"{mode}: live namespace and host cleanup assertions passed")
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()


with tempfile.TemporaryDirectory(prefix="tau-scratch-cleanup-") as directory:
    work = Path(directory)
    for protected in (False, True):
        case = work / str(protected)
        case.mkdir()
        with tempfile.TemporaryDirectory(prefix="isolate-unrelated-") as other:
            run_case(case, Path(other), sys.argv[1], protected)
