---
name: self-pr-grooming
description: Review the bot's own open Fedimint PRs, close obsolete ones, and remind maintainers about pending decisions.
user-invocable: true
advertise: true
---

# Groom the bot's own PRs

Use this scheduled task only for the grooming below. Do not make unsolicited code
changes, update branches, merge PRs, or groom other authors' PRs. Load
`fedimint-bot-github-cli`; keep its broker and publication safeguards.

1. Enumerate all open PRs authored by `fedimint-tau` in `fedimint/fedimint`,
   `fedimint/fedimint-sdk`, and `fedimint/fedimint-infra`, including drafts.
   Use `gh pr list -R OWNER/REPO
   --state open --author fedimint-tau --limit 1000`; if you reach the limit,
   report incomplete coverage rather than claim a complete sweep. Verify each
   candidate's author with `gh api repos/OWNER/REPO/pulls/NUMBER`: login
   `fedimint-tau`, numeric user ID `332691140`. A `tau/` branch is not ownership.
2. Read the diff, discussion, reviews, checks, and current trunk as needed. Decide
   whether each PR remains useful and relevant. Close clearly superseded,
   already-solved, or no-longer-useful PRs with a brief evidence-based comment,
   then `gh pr close NUMBER -R OWNER/REPO` (never delete its branch). Recheck
   authorship, open state, and any new discussion immediately before acting;
   verify the result. Age, inactivity, or failing checks alone do not justify
   closure. Leave uncertain cases open and ask maintainers to decide.
3. For useful PRs still waiting on maintainers, send one concise consolidated
   reminder via `maintainer_discord_send` to the configured
   `fedimint_maintainers` destination: full PR URLs, why each still matters, and
   the decision needed. Include uncertain closure candidates; omit PRs waiting
   only on the bot. Never add destinations or post repetitive PR comments.
4. Keep a durable Clank grooming record with decisions and reminder outcomes.
   Skip an already completed day's sweep; do not overlap an in-flight sweep.
   Remind at most once per PR per seven days unless its required decision
   materially changes. Record intent before sending and the result afterward;
   do not retry sends with uncertain outcomes without checking delivery. If
   Discord is unavailable, retain the pending reminder and report the blocker,
   not success. No pending decisions means no reminder.
