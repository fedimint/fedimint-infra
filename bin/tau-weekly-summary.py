"""Send one weekly-summary instruction; never retry an uncertain delivery."""

import argparse
from datetime import datetime, timedelta, timezone
import subprocess
from zoneinfo import ZoneInfo


MONTHS = (
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
)
CORE_REPO = "fedimint/fedimint"
SDK_REPO = "fedimint/fedimint-sdk"
TARGETS = {
    CORE_REPO: ("fedimint-weekly", ("general", "fedimint_maintainers")),
    SDK_REPO: ("fedimint-sdk-weekly", ("sdk",)),
}


def reporting_window(now):
    end = now.astimezone(timezone.utc).replace(microsecond=0)
    return end - timedelta(hours=184), end


def timestamp(value):
    return value.strftime("%Y-%m-%dT%H:%M:%SZ")


def instruction(repo, start, end, announce_channel):
    prefix, _ = TARGETS[repo]
    occurrence = f"{prefix}-{end.strftime('%Y%m%dT%H%M%SZ')}"
    date = end.astimezone(ZoneInfo("America/Los_Angeles"))
    label = f"{date.day} {MONTHS[date.month - 1]}, {date.year}"
    filename = f"Week-summary-{label.replace(' ', '-')}.md"
    message = (
        "Add a scheduled weekly development-summary task to your work queue: in "
        f"{repo}, use the fedimint-bot-weekly-dev-summary skill and "
        f"publish to https://github.com/{repo}/wiki.\n"
        f"Repository argument: {repo}.\n"
        f"Occurrence ID: {occurrence}.\n"
        "Reuse any existing durable task for this repository and exact window.\n"
        "UTC activity window: "
        f"{timestamp(start)} <= activity time < {timestamp(end)}.\n"
        f"Markdown heading: '# Week summary: {label}'. "
        f"Wiki filename: '{filename}'.\n"
    )
    if announce_channel:
        message += (
            "After verified publication, send the public wiki page URL via "
            f"discord_send to {announce_channel} as a plain link without mentions.\n"
        )
    return message


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tau", help="absolute path to the installed Tau binary")
    parser.add_argument("--repo", choices=TARGETS, default=CORE_REPO)
    parser.add_argument(
        "--announce-channel",
        choices=[channel for _, channels in TARGETS.values() for channel in channels],
        help="configured Discord alias for the verified public wiki link",
    )
    parser.add_argument(
        "--window-end",
        help="original captured UTC end for an operator-approved rerun "
        "(YYYY-MM-DDTHH:MM:SSZ)",
    )
    args = parser.parse_args()
    if args.announce_channel and args.announce_channel not in TARGETS[args.repo][1]:
        parser.error("--announce-channel is not configured for the selected repository")
    if args.window_end:
        try:
            end = datetime.strptime(
                args.window_end, "%Y-%m-%dT%H:%M:%SZ"
            ).replace(tzinfo=timezone.utc)
        except ValueError:
            parser.error("window end must be YYYY-MM-DDTHH:MM:SSZ")
        start, end = reporting_window(end)
    else:
        start, end = reporting_window(datetime.now(timezone.utc))
    print(f"Sending {args.repo} weekly summary window {timestamp(start)} to {timestamp(end)}",
          flush=True)
    # No --wait-response, no harness startup, and no retry on any failure.
    result = subprocess.run(
        [args.tau, "message", "&tau-fedimint-bot"],
        input=instruction(args.repo, start, end, args.announce_channel),
        text=True,
        check=False,
    )
    if result.returncode == 0:
        print("Delivery acknowledged; report completion is not observed.", flush=True)
    return result.returncode if result.returncode >= 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
