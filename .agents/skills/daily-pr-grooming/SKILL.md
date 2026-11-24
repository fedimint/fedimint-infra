---
name: daily-pr-grooming
description: Maintain open PRs across watched repositories and send one daily Discord reminder grouped by who needs to act.
user-invocable: true
advertise: true
---

# Daily PR grooming

## Start or resume the day

Use the UTC day and repository scope admitted by the coordinator. Limit PR
reads, actions, and reminders to that scope. Keep one private Clank record per
UTC day across deliveries. Save each delivery reference and scope, repository
coverage, selected PRs, next actions, and write receipts. Key PR state by
repository and number.

Run one pass at a time and coordinate with event-driven reviews and weekly
triage. Record the intent and any relevant head SHA before every write. Save
the verified result or blocker and resolve pending writes before retrying.
When resuming, reconcile read-only until the coordinator's same-day resume
rule permits writes.

Record which repositories you finished under the day's limits. On repeat
deliveries, skip completed work and reuse earlier coverage and receipts.
Spend the remaining budget on repositories still due. Mark the scheduled run
complete only during a scheduled pass and only after accounting for the full
watchlist. Carry unresolved actions across days without replaying writes or
digests.

When the coordinator admits an additional third-party batch, reuse the day's
record. Select additional PRs only in the named repository, even if its ordinary
coverage is complete. Record the original delivery, repository, and additional
limit once. Count distinct new selections against that limit. Exclude PRs already
selected that UTC day, including blocked or skipped selections. On retry, reconcile
the saved batch and keep its count. Use the extra allowance only for that batch
and repository. Recheck pending bot and Dependabot work within scope without
repeating completed writes. Keep the one-reminder limit.
Mark each selection as ordinary or supplementary. Track supplementary
coverage separately: the extra batch neither spends the ordinary budget nor
marks a repository complete for the ordinary pass. Skip PRs already selected
in the extra batch when ordinary selection resumes that day.

## Build the inventory and select PRs

Follow **Compact open PR inventory** in `fedimint-bot-github-cli`. Keep only
`number`, `updatedAt`, `createdAt`, `isDraft`, `author`, and `title` in the
inventory. Keep exact timestamps and native author identity. A missing draft
flag means unknown; resolve it in the per-PR read after selection.

Select verified bot and Dependabot candidates separately from third-party PRs.
For third-party triage, consider PRs with no activity in the last **48 hours**
across repositories still due in the admitted scope. Sort by `updatedAt`
(oldest first), then repository and number. Select PRs you haven't examined
or that have changed materially since triage. A skipped draft becomes
eligible when it passes the draft age cutoff below. Revisit blocked work when
its blocker clears. Skip daily retriage if nothing material has changed and
the same action is still with the same person.

Checkpoint the selection before fetching richer data. Count each selected
third-party PR once against the shared **50-PR cap per UTC day** or the separately
admitted batch limit, even if the work later blocks or you skip it. If the
inventory is incomplete, report the gap, keep that scope's third-party
selection pending, and continue only bot or Dependabot work you can verify.

Fetch review, check, mergeability, head, and discussion details only for
selected PRs or recorded actions that need rechecking before a reminder.
Verify eligibility, discussion, and head before each action. Changed or
uncertain evidence does not authorize action. Record each PR's outcome, who
needs to act next, and any notifications sent.

## Handle selected PRs

### Our PRs

Check every open PR authored by `fedimint-tau` (verify GitHub ID `332691140`),
including drafts. Read the diff, discussion, checks, and current trunk. Address
feedback, fix CI or conflicts, and move the PR forward. If the PR is
superseded, the problem is already solved, or the PR no longer serves a
purpose, close it with a short explanation and leave the branch intact. Age,
inactivity, or failing checks alone do not justify closure. Leave uncertain
cases open for a human decision.

Delegate scoped fixes to one engineer per main checkout. Identify the
verified bot-owned head repository, ref, and SHA. Preserve other contributions
and use a checked, reviewed fast-forward update to the dedicated `tau/` branch.
A rewrite requires separate authority under `fedimint-bot-pr-branch-rewrite`.
Grooming does not authorize merging our own PRs.

### Dependabot

Handle every open Dependabot PR end to end. Follow `fedimint-bot-dependabot`
for admission, independent review, fork CI, replacements, SHA-bound approval,
and merging or queueing. Apply repository review instructions within those limits
(for Fedimint, `github-cargo-dependabot-review` or
`github-actions-dependabot-review`). Count a prior review as evidence only for
its verified SHA and scope. Approve CI if needed and safe. Approve a passing
update and merge it or use the required queue through the normal repository
process. If the update needs fixes, link the corrected replacement before
closing the original. If evidence, checks, a
safe checkout, or a permitted operation is unavailable, record what remains
pending. If human judgment is needed, record the decision and who can make it.

### Other inactive PRs

- For a draft opened **more than a week ago** (use `createdAt`), verify
  eligibility, close the PR, and verify closure before posting an invitation
  to reopen when ready for review. Checkpoint the invitation as a separate write:
  commenting first changes the inactivity timestamp. Skip younger drafts.
- For failing CI or merge conflicts, record the specific action the author
  needs to take. Treat pending CI as pending, not failed.
- For a PR potentially ready to merge, use the requested teams and team
  membership reads in `fedimint-bot-github-cli`. Use `fedimint/firehose` only
  if it is the only requested team. Treat unreadable membership as unknown.
  Only if no team was requested, use the repository's authoritative
  maintainer roster or humans with verified `write` or `admin` permission
  from a complete collaborator roster. Exclude the author and bots,
  deduplicate, and choose randomly (e.g. `shuf -n 1`). Keep that reviewer
  while the same action is outstanding. Use `maintainers-contact-information`
  to map identities, not to verify repository permissions.

## Send one work reminder

Share one reminder batch per UTC day across all passes. Verify that the recorded
actions still apply, and check prior notices to avoid duplicate pings across
channels. If nobody needs to act, skip the reminder. Freeze the scoped actions
and any GitHub fallback before the first send. A later admitted pass can send
the day's reminder if no earlier pass attempted delivery. After delivery
starts, leave newly found actions pending for the next day.

Group actions by person and send at most **one public `discord_send` message
per UTC day to `general`**. Use verified `<@ID>` mentions, full PR URLs, and
short, safe next steps. Omit untrusted mentions, raw PR text, and private
findings. For a long digest, attach a safe Markdown list to the same message
or record the overflow as pending.

```text
## @handle
* <PR link> — Fix reconnect handling: re-review the author’s cancellation fix.
* <PR link> — Update release build: resolve the conflict in Cargo.lock.
```

If you don't know the person's Discord handle, mention `@username` on one
eligible GitHub PR in scope. Check the recipient's recorded notification history
across the watchlist. Don't ping the same person on GitHub more than once in
seven days. After that, ping them only for a new action. If ruling out a
duplicate would require reading outside the admitted scope, leave the ping
pending.

Record unavailable routes and uncertain deliveries. Treat an uncertain
`general` send as spent until you can verify the outcome; the channel is
send-only.

## Report trial findings when requested

When the coordinator admits a trial report requested by the operator, send
one report to `fedimint_maintainers`, separate from the work reminder. Include
the scope, outcome, and any skill mistakes or blockers. Use safe evidence and
the same write receipts. Omit role pings.
