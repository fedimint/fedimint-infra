"""Send one weekly-summary instruction; never retry an uncertain delivery."""

import argparse
from datetime import datetime, timedelta, timezone
import subprocess


def reporting_window(now):
    end = now.astimezone(timezone.utc).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    end -= timedelta(days=end.weekday())
    return end - timedelta(days=7), end


def timestamp(value):
    return value.strftime("%Y-%m-%dT%H:%M:%SZ")


def instruction(start, end):
    occurrence = f"fedimint-weekly-{end.strftime('%Y%m%dT%H%M%SZ')}"
    return (
        f"Scheduled weekly development summary. Occurrence ID: {occurrence}.\n"
        "Load and execute the installed fedimint-weekly-dev-summary skill for "
        "fedimint/fedimint, including publication to its GitHub wiki.\n"
        f"Use exactly this half-open UTC activity window: "
        f"{timestamp(start)} <= activity time < {timestamp(end)}.\n"
        "For a rerun, reconcile/update the same deterministic report page; "
        "do not create a second report. Follow the skill's evidence, access, "
        "and safe-publication rules. If blocked, retain the draft and report "
        "the blocker rather than claim publication succeeded.\n"
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tau", help="absolute path to the installed Tau binary")
    parser.add_argument(
        "--window-end",
        help="explicit Monday 00:00 UTC end for an operator-approved rerun "
        "(YYYY-MM-DDTHH:MM:SSZ)",
    )
    args = parser.parse_args()
    if args.window_end:
        try:
            end = datetime.strptime(
                args.window_end, "%Y-%m-%dT%H:%M:%SZ"
            ).replace(tzinfo=timezone.utc)
        except ValueError:
            parser.error("window end must be YYYY-MM-DDTHH:MM:SSZ")
        start, normalized_end = reporting_window(end)
        if end != normalized_end:
            parser.error("window end must be Monday 00:00:00 UTC")
    else:
        start, end = reporting_window(datetime.now(timezone.utc))
    print(f"Sending weekly summary window {timestamp(start)} to {timestamp(end)}",
          flush=True)
    # No --wait-response, no harness startup, and no retry on any failure.
    result = subprocess.run(
        [args.tau, "message", "&tau-fedimint-bot"],
        input=instruction(start, end),
        text=True,
        check=False,
    )
    if result.returncode == 0:
        print("Delivery acknowledged; report completion is not observed.", flush=True)
    return result.returncode if result.returncode >= 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
