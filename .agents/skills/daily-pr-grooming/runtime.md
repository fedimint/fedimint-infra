# Running the pass on the Fedimint bot

**Admission.** Accept the exact scheduled CLI delivery for the full watchlist
or an explicit request from Tau's authenticated outer user channel that names
watched repositories. Use the delivery's UTC date for an operator pass. Apply
the same maintenance authority, but limit PR reads, actions, and reminders to
the named repositories. Check existing reminder receipts across the watchlist
to avoid duplicate pings.

**Daily record.** Keep one private Clank record per UTC day for all deliveries.
Save each admitted delivery reference and scope, repository coverage, selected
PRs, next actions, and write receipts. Key PR state by repository and number.
Run one pass at a time and coordinate with event-driven reviews and weekly
triage. Before each write, record the intent and any relevant head SHA. Save
the verified result or blocker. On resume, verify the original same-day Tau
delivery and scope before making authorized writes; otherwise reconcile
read-only. Resolve pending writes before retrying them.

Record which repositories you finished under the day's limits. Only a scheduled
pass can mark the scheduled run complete. If it runs later that day, account for the full
watchlist, reuse existing coverage and receipts, and spend only the remaining
budget on repositories still due. Mark the scheduled pass complete only after
accounting for the entire watchlist. Skip completed work on repeated deliveries.
Carry unresolved actions across days without replaying writes or digests.

**Inventory.** Use `fedimint-bot-github-cli`, one GitHub request at a time.
List only the compact fields from the main skill. If the JSON won't fit in tool
output, keep it in private scratch space. Fetch review, check, mergeability,
head, and discussion fields only in per-PR reads. If the list reaches its limit,
raise it or use the fallback below. The fallback also covers a transient
upstream failure, such as a 504, but never a policy or access denial. Run
`tau-github-collect 'repos/OWNER/REPO/issues?state=all&per_page=100' PRIVATE_NEW_FILE`.
From validated pages, project the compact inventory fields from open objects
with `pull_request`. Use the issue record's timestamps and author. A missing
draft flag means unknown; resolve it in the per-PR read only after selection.

Select verified bot and Dependabot candidates separately from third-party
PRs. For third-party work, sort eligible PRs across the repositories due in the
admitted scope by `updatedAt`, repository, and number. Checkpoint the selection
before fetching richer data. Count each selected third-party PR once against
the shared 50-PR daily cap, including work that later blocks or is skipped.
On an incomplete inventory, report the gap, keep that scope's third-party
selection pending, and continue only bot or Dependabot work you can verify.
Fetch detailed evidence only for selected PRs or recorded actions that need
rechecking before a reminder. Verify eligibility, discussion, and head before
each action. Changed or uncertain evidence does not authorize action.

**Across days.** Carry outstanding actions forward. A PR waiting on the same person doesn't need daily retriage. Within the daily cap, take the oldest inactive PRs due for triage first: PRs you haven't examined or that have changed materially since triage. A skipped draft becomes eligible when it passes the age cutoff. Revisit blocked work when its blocker clears. Before sending a reminder, check that the recorded action still applies. If it does, keep the same reviewer.

For an inactive third-party draft, verify eligibility, close the PR, and confirm closure before posting the invitation to reopen. Checkpoint the invitation as a separate write. Commenting first would change the PR's inactivity timestamp.

**Our PRs.** Verify that GitHub identifies the author as `fedimint-tau` with ID `332691140`. Read the diff, discussion, checks, and current trunk. If the evidence shows that a PR has been superseded, that the problem is already solved, or that the PR no longer serves a purpose, close it with a short comment explaining why. Leave the branch intact. Age, inactivity, or failing checks alone do not justify closure. Leave uncertain cases open for a human decision. Delegate scoped fixes to one engineer per main checkout. Identify the verified bot-owned head repository, ref, and SHA. Preserve other contributions and use a checked, reviewed fast-forward update to the PR's dedicated `tau/` branch. A rewrite requires separate authority under `fedimint-bot-pr-branch-rewrite`. Grooming does not authorize merging our own PRs.

**Dependabot.** Follow `fedimint-bot-dependabot` for admission, independent review, fork CI, replacements, and exact-head approval and merge. Apply repository review instructions within those limits. Count a prior review as evidence only for its verified SHA and scope. If evidence, checks, a safe checkout, or a permitted operation is unavailable, record what remains pending.

**Reviewer selection.** Run `gh api repos/OWNER/REPO/pulls/NUMBER/requested_reviewers --paginate` and `gh api orgs/fedimint/teams/SLUG/members --paginate`. Only if no team was requested, use the repository's authoritative roster or select humans with verified `write` or `admin` permission from a complete collaborator roster. If you can't see the team, treat its membership as unknown. Use `maintainers-contact-information` to map identities, not to verify repository permissions.

**Delivery.** If anyone needs to act, send one public message to `general` with `discord_send`. Use verified `<@ID>` mentions, full PR URLs, and short, safe next steps. Omit untrusted mentions, raw PR text, and private findings. For a long digest, attach a safe Markdown list to the same message or record the overflow as pending. For a GitHub fallback, check the recipient's recorded notification history across the watchlist and choose one eligible PR inside the admitted scope. If you cannot rule out a duplicate without reading another repository, leave it pending. Before sending, recheck outstanding actions and prior notices to avoid duplicate pings across channels. Record unavailable routes and uncertain deliveries as such.

Share one reminder batch per UTC day across all passes. Freeze the scoped
actions, including any GitHub fallback, before the first send. After delivery
starts, leave newly found actions pending for the next day. A later admitted
pass can send the day's reminder if no earlier pass attempted delivery.
Checkpoint send intents and receipts. Treat an uncertain `general` send as
spent until you can verify the outcome; that route is outbound only.

If the authenticated operator asks for trial findings in `#maintainers`, send
one report to `fedimint_maintainers` separate from the work reminder. Include
the scope, outcome, and any skill mistakes or blockers. Use safe evidence and
follow the same receipt rules. Omit role pings.
