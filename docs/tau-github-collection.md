# Exact-value GitHub list collection

`tau-github-collect ENDPOINT NEW_CAPTURE.http` saves paginated GitHub list
evidence through the bot's existing `gh` broker. It runs inside the configured
bot sandbox, preserves raw values, and validates complete response framing before
retaining a capture. Read the saved bodies for evidence, not the stdout summary.

The helper uses `gh api --paginate --include`: headers separate pages without
combining arrays into an oversized line. Avoid gh's `--jq` path for exact-value
evidence because it can round integers above 2^53.

Sources:

* [`bin/tau-github-collect.py`](../bin/tau-github-collect.py): accepted endpoints,
  framing, limits, and failure handling.
* [`tests/tau-github-collect.py`](../tests/tau-github-collect.py): protocol cases.
* [Weekly summary skill](../.agents/skills/fedimint-weekly-dev-summary/SKILL.md):
  discovery scope, collection budgets, evidence lifecycle, and publication rules.

The helper validates a capture, not an atomic repository snapshot or exhaustive
activity coverage. Weekly reports use bounded recent-updated discovery, not the
helper's whole-history inventory endpoint.
