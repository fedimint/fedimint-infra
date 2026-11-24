---
name: daily-pr-grooming
description: Maintain open PRs across watched repositories and send one daily Discord reminder grouped by who needs to act.
user-invocable: true
advertise: true
---

# Daily PR grooming

For the configured bot, apply [the runtime notes](runtime.md) throughout.

Start with a compact inventory for each watched repository. This is a helper template: change the repo, fields, filters, or limit to suit the queue. Each row is PR number, last update, draft/review state, author, labels, and title, oldest update first.

```bash
repo=fedimint/fedimint
gh pr list -R "$repo" --state open --limit 500 \
  --json number,updatedAt,isDraft,reviewDecision,author,labels,title \
  --jq 'sort_by(.updatedAt)[] | [
    .number, .updatedAt[:10],
    (if .isDraft then "DRAFT"
     elif (.reviewDecision // "") == "" then "-"
     else .reviewDecision end),
    .author.login, ([.labels[].name] | join(",")), .title
  ] | @tsv'
```

The shortened date is for scanning. Use the full `updatedAt` for the 48-hour cutoff, and `createdAt` for draft age. If the inventory hits its limit, fetch the rest before choosing the oldest PRs.

## Run one daily pass

1. **Our PRs:** Check every open PR authored by the agent, including drafts. Address feedback, fix CI or conflicts, and move the PR forward. If someone else needs to act, record who and why.
2. **Dependabot:** Handle every open Dependabot PR end to end. Follow the repository’s dependency review instructions (for Fedimint: `github-cargo-dependabot-review` or `github-actions-dependabot-review`). Approve CI if needed and safe. If the reviewed update looks good and required checks pass, approve and merge through the normal repo process. If it needs fixes, open a corrected replacement, link it, then close the original. If human judgment is needed, record the decision and who can make it.
3. **Other inactive PRs:** Across all watched repositories, take at most **50 per day** with no activity in the last **48 hours**, oldest activity first. Exclude PRs covered above. For each:
   - If it is a draft and the PR was opened **more than a week ago**, close it with a comment inviting the author to reopen when ready for review. Skip younger drafts.
   - If CI is failing or there are merge conflicts, record the specific action the author needs to take. Treat pending CI as pending, not failed.
   - If potentially ready to merge, pick a reviewer from the requested teams. For Fedimint, use `fedimint/firehose` only if it is the only requested team. If no team was requested, use the repository’s maintainer roster. Exclude the author and bots, deduplicate, and choose randomly (e.g. `shuf -n 1`). Keep that reviewer while the same action is outstanding.

**Write down the outcome after every PR**, including anything done, who needs to act next, and any notification already sent. Keep this record across runs so a harness restart can resume the day’s pass without repeating work or pings.

## Send one work reminder

Collect outstanding actions across repositories, group them by person, and send **one message to `#general` on Discord**. Use known Discord mentions and describe the actual next step:

```text
## @handle
* <PR link> — Fix reconnect handling: re-review the author’s cancellation fix.
* <PR link> — Update release build: resolve the conflict in Cargo.lock.
```

If there is no known Discord handle, mention `@username` on the relevant GitHub PR instead. Don’t ping the same person on GitHub more than once in seven days across the watchlist. Even after a week, leave the previous mention alone if the same action is still in their court. If they addressed it, notify them only when there is a new action for them. If nobody needs to act, skip the reminder.
