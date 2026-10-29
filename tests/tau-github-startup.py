"""Check the deployed notifier's protocol and generated config without live credentials.

Run only in the network-isolated Nix build sandbox. Stop at startup readiness;
this does not assert GitHub connectivity or exercise live notification delivery.
"""

import json
import signal
import subprocess
import sys

import cbor2


def timeout(_signum, _frame):
    raise TimeoutError("notifier startup did not finish")


signal.signal(signal.SIGALRM, timeout)
signal.alarm(30)

with open(sys.argv[2], encoding="utf-8") as source:
    config = json.load(source)["extensions"]["github-notifications"]["config"]

with subprocess.Popen(
    [sys.argv[1]], stdin=subprocess.PIPE, stdout=subprocess.PIPE, bufsize=0
) as process:
    try:
        decoder = cbor2.CBORDecoder(process.stdout)
        hello = decoder.decode()
        assert hello["message"] == "hello", hello
        assert hello["payload"]["protocol_version"] == {"major": 14, "minor": 0}, hello
        cbor2.dump(
            {
                "message": "configure",
                "payload": {
                    "instance_name": "github-notifications",
                    "harness_protocol_version": {"major": 14, "minor": 0},
                    "config": config,
                    "secrets": {
                        config["token_secret"]: "offline-test-token",
                        config["identity_key_secret"]: "01" * 32,
                    },
                },
            },
            process.stdin,
        )
        process.stdin.flush()
        for _ in range(32):
            message = decoder.decode()
            assert message["message"] != "config_error", message
            if message["message"] == "ready":
                break
        else:
            raise AssertionError("notifier did not declare readiness")
    finally:
        process.kill()
        process.wait()
        signal.alarm(0)
