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

# Match the locked Tau harness and GitHub extension protocol versions. A
# compatible extension may use an older minor of the same wire major.
harness_protocol = {"major": 29, "minor": 1}
notifier_protocol = {"major": 29, "minor": 1}

with open(sys.argv[2], encoding="utf-8") as source:
    config = json.load(source)["extensions"]["github-notifications"]["config"]

assert config["filtered_unread_expiry_seconds"] == 7 * 24 * 60 * 60

with subprocess.Popen(
    [sys.argv[1]], stdin=subprocess.PIPE, stdout=subprocess.PIPE, bufsize=0
) as process:
    try:
        decoder = cbor2.CBORDecoder(process.stdout)
        hello = decoder.decode()
        assert hello["message"] == "hello", hello
        assert hello["payload"]["protocol_version"] == notifier_protocol, hello
        cbor2.dump(
            {
                "message": "configure",
                "payload": {
                    "instance_name": "github-notifications",
                    "harness_protocol_version": harness_protocol,
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
        mark_read = None
        for _ in range(32):
            message = decoder.decode()
            assert message["message"] != "config_error", message
            if message["message"] == "emit":
                event = message["payload"]["event"]
                if event["event"] == "tool.registration_declared":
                    tool = event["payload"]["tool"]
                    if tool.get("model_visible_name") == "github_mark_read":
                        assert mark_read is None, message
                        mark_read = tool
            if message["message"] == "ready":
                break
        else:
            raise AssertionError("notifier did not declare readiness")
        assert mark_read is not None, "notifier did not register github_mark_read"
        assert mark_read["enabled_by_default"] is False, mark_read
        assert mark_read["parameters"] == {
            "type": "object",
            "properties": {"notification_id": {"type": "string"}},
            "required": ["notification_id"],
            "additionalProperties": False,
        }, mark_read
    finally:
        process.kill()
        process.wait()
        signal.alarm(0)
