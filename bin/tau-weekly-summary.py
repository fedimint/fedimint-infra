"""Send one weekly-summary instruction; never retry an uncertain delivery."""

import argparse
from datetime import datetime, timedelta, timezone
import subprocess
from zoneinfo import ZoneInfo


MONTHS = (
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
)


def reporting_window(now):
    end = now.astimezone(timezone.utc).replace(microsecond=0)
    return end - timedelta(hours=184), end


def timestamp(value):
    return value.strftime("%Y-%m-%dT%H:%M:%SZ")


def instruction(start, end):
    occurrence = f"fedimint-weekly-{end.strftime('%Y%m%dT%H%M%SZ')}"
    date = end.astimezone(ZoneInfo("America/Los_Angeles"))
    label = f"{date.day} {MONTHS[date.month - 1]}, {date.year}"
    filename = f"Week-summary-{label.replace(' ', '-')}.md"
    return (
        f"Scheduled weekly development summary. Occurrence ID: {occurrence}.\n"
        "Load and execute the installed fedimint-weekly-dev-summary skill for "
        "fedimint/fedimint, including publication to its GitHub wiki.\n"
        f"Use exactly this half-open UTC activity window: "
        f"{timestamp(start)} <= activity time < {timestamp(end)}.\n"
        "This is a rolling 184-hour lookback (7 days plus 16 hours), with "
        "intentional overlap. Deduplicate items within this report, but do not "
        "omit activity because a previous report included it. Do not resample "
        "the current time or substitute calendar-week boundaries.\n"
        f"Use the exact Markdown heading '# Week summary: {label}' and wiki "
        f"filename '{filename}', derived from the endpoint's "
        "America/Los_Angeles date. The colon belongs only in the heading, not "
        "the filename. Do not create a second timestamp-named page.\n"
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
        help="original captured UTC end for an operator-approved rerun "
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
        start, end = reporting_window(end)
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
