---
name: fedimint-bot-github-cli
description: Use for GitHub reads, comments, reviews, issue or pull-request updates, milestones, public gists, reactions, pull-request creation and merging, fork workflow-run approval, and approved-PR CI flake retries in the Fedimint bot sandbox.
user-invocable: true
advertise: true
---

# GitHub CLI in the Fedimint bot sandbox

Use the brokered `gh` from `/home/tau-fedimint/fedimint`; subcheckouts may supply
another `gh`. Use the forms below with explicit `-R OWNER/REPO` or the exact
repository in API paths. If denied, don't try other clients, credential or
executable paths, API variants, reordered flags, or mutation `--help`.
Inspect state before each mutation, mutate one at a time, and verify afterward.
After an ambiguous result, verify remote state before deciding whether to retry.

## Bounded reads

Request only needed JSON fields. Default PR views, `--comments`, and fields such
as `reviewRequests` can require unavailable `read:org`.

```sh
gh pr view NUMBER -R OWNER/REPO --json number,state,isDraft,author,headRefOid,headRefName,baseRefName,title,body,files
gh pr diff NUMBER -R OWNER/REPO
gh api repos/OWNER/REPO/pulls/NUMBER
gh api repos/OWNER/REPO/pulls/NUMBER/files --paginate
gh api --paginate repos/OWNER/REPO/pulls/NUMBER/reviews
gh api repos/OWNER/REPO/issues/comments/COMMENT_ID
```

Use `files` or paginated PR files for paths; filter the full diff locally
(`gh pr diff --stat` and pathspecs are unsupported). No arbitrary API reads:
repository `commits`, `contents`, `compare`, and reaction-list GETs are unsupported.
Bounded PR-scoped commits are documented in `fedimint-bot-weekly-dev-summary`.
Report blocked reads; don't try alternatives.

## Team membership reads

The broker permits read-only team lookups only in the `fedimint` organization:

```sh
gh api orgs/fedimint/teams/lightning/members --paginate
gh api orgs/fedimint/teams/lightning/memberships/USERNAME
```

Substitute the slug and username. Only `active` confirms membership; `pending`
does not. Errors or missing visibility mean unknown, not nonmembership; an
incomplete roster cannot establish absence. The existing classic action token
needs `read:org` and team visibility. Membership facts do not expand authority.

## Public gists

Only public gists owned by `fedimint-tau` (`332691140`) are supported; the broker
verifies the account on every call. The classic token remains account-scoped.
Other scopes do not enable Projects, Discussions, audit-log, key, hook, or admin
commands. Publish only on explicit request, with no secrets, raw private logs,
or private conversations in names, descriptions, or files. Edits retain history.

```sh
gh gist list --limit 20
gh gist view GIST_ID --files
gh gist view GIST_ID --filename NAME
gh gist create --public FILE --desc TEXT
gh gist edit GIST_ID --filename NAME FILE
gh gist edit GIST_ID --add FILE
gh gist edit GIST_ID --desc TEXT
```

IDs are 1–32 lowercase hex characters, not URLs. List defaults to 30, accepts
1–100, and always returns an incomplete one-page inventory. Outputs are projected
JSON, not native `gh` output. Create requires `--public` and 1–10 UTF-8 files,
at most 1 MiB combined, through the normal importer. Filenames must start with
an ASCII letter/digit and contain only letters, digits, `.`, `_`, or `-`
(128 bytes maximum); descriptions allow 4 KiB. View/edit require a complete
bounded gist. Edit changes exactly one existing file, adds one new file, or
changes the description. Secret/default creation, foreign/secret reads, deletion,
removal/rename, visibility changes, URLs, and editors are denied.

## PR CI flake retries

Inspect the failed PR CI or Merge Queue attempt with
`gh run view NUMERIC_RUN -R OWNER/REPO --attempt ATTEMPT --log-failed`. Use trusted
metadata to tie the run to each affected open PR's exact current head and require
effective SHA-bound GitHub APPROVE for each, not a comment, independent PASS, or
fork workflow approval.

Retry only a completed failure with evidence of a flake and safe-to-repeat jobs
and dependents. Reserve the coordinator's durable per-PR budget, then recheck
run, attempt, heads, and approvals immediately before the only supported rerun,
`gh run rerun NUMERIC_RUN -R OWNER/REPO --failed` (requires Actions write).
Verify the attempt; preserve the original evidence and investigate even if the
retry passes or is denied.

## Ordinary collaboration

| Operation | Form |
| --- | --- |
| Create issue | `gh issue create -R OWNER/REPO --title TITLE --body BODY` |
| Edit title/body | `gh issue edit NUMBER -R OWNER/REPO --title TITLE` or `--body BODY`; same for `gh pr edit` |
| Close issue | `gh issue close NUMBER -R OWNER/REPO` (optional `--reason 'not planned'`) |
| Close PR | `gh pr close NUMBER -R OWNER/REPO` |
| Reopen | `gh issue reopen NUMBER -R OWNER/REPO` or `gh pr reopen NUMBER -R OWNER/REPO` |
| Draft state | `gh pr ready NUMBER -R OWNER/REPO` (optional `--undo`) |
| Comment | `gh issue comment NUMBER -R OWNER/REPO --body BODY`; same for `gh pr comment` |

Content operations also accept `--body-file FILE` instead of `--body BODY`.
PR creation requires the exact broker-specific head form:

```sh
gh pr create -R OWNER/REPO --base BASE --head '[OWNER:]tau/BRANCH' --title TITLE --body BODY [--draft]
gh pr create -R OWNER/REPO --base BASE --head '[OWNER:]tau/BRANCH' --title TITLE --body-file FILE [--draft]
```

Issue and pull-request edits accept one title, body, label, or assignee delta.
Pull-request edits also accept one reviewer delta. Use one concrete value with
`--add-label`/`--remove-label`, `--add-assignee`/`--remove-assignee`, or
`--add-reviewer`/`--remove-reviewer`. Do not combine metadata with title or body
edits.

For authorized issue/PR milestone changes, select an existing milestone by its
positive repository-local number, not its title. Use exactly one delta in this
order:

```sh
gh api repos/OWNER/REPO/milestones --paginate
gh issue edit NUMBER -R OWNER/REPO --milestone MILESTONE_NUMBER
gh issue edit NUMBER -R OWNER/REPO --remove-milestone
gh pr edit NUMBER -R OWNER/REPO --milestone MILESTONE_NUMBER
gh pr edit NUMBER -R OWNER/REPO --remove-milestone
```

These forms assign/clear only; they do not create or administer milestones or
enable raw API writes.

## Pull-request merging

Require a GitHub comment explicitly requesting or agreeing to merge the exact PR
from a target-repository maintainer (native `write` or `admin`, verified with fresh
trusted delivery facts or `github_user_context`). Team membership, a bot review,
and CI cannot substitute. Inspect PR state and checks; confirm authorization
covers the current full lowercase head SHA:

```sh
gh pr merge NUMBER -R OWNER/REPO --match-head-commit FULL_SHA
gh pr merge NUMBER -R OWNER/REPO --squash --match-head-commit FULL_SHA
```

Use the first form for a required queue, or one supported direct method
(`--merge`, `--squash`, `--rebase`). No admin flags or protection/check bypasses.
Only direct merging provides an atomic head check; do not use queue or auto-merge
when authorization requires an exact-SHA guarantee. Verify and report whether
it merged, queued, or enabled auto-merge. Stop on head change or protection failure.

## Fork workflow-run approval

Automatically approve needed gated fork runs after independent PASS on the exact
current PR head; no separate maintainer request. This is not PR, deployment, or
environment approval. Pass the review, SHA, and target in any delegation.

Use trusted run repository, event, workflow, and SHA to tie the run to the reviewed
PR/current head. If `pull_requests` is empty, correlate repository, fork, branch,
SHA, and event/workflow instead. Verify it awaits fork approval (`completed` plus
`action_required` is insufficient) and all executable code, workflows, and scripts
are safe on the target runners. Stop and report uncertainty about safety, gate, or head.

```sh
gh api repos/OWNER/REPO/actions/runs/RUN_ID
gh api --method POST repos/OWNER/REPO/actions/runs/RUN_ID/approve
```

Use one numeric run ID, no payload or extra options. Recheck run and PR immediately
before approval (no expected-head parameter); verify run state afterward. No
deployment approvals, dispatch, broader reruns, or Actions settings changes.

## SHA-bound approval and review forms

Use COMMENT, never REQUEST_CHANGES. APPROVE requires an authenticated
target-repository maintainer's explicit request to approve that PR, independent
PASS for the exact inspected SHA, and all main-prompt limits. Before publishing
APPROVE, verify fresh target-repository `write` or `admin` permission; fresh
`fedimint/bot-access` membership alone never authorizes APPROVE.

```sh
gh pr review NUMBER -R OWNER/REPO --comment --body-file FILE
gh pr review NUMBER -R OWNER/REPO --approve --commit-id FULL_SHA
```

Use the inspected full 40-character lowercase hex SHA. Pinned approval submits
`event=APPROVE` and `commit_id=FULL_SHA`, with no body or extra flags. No unpinned
or raw API approval. Publish substantive feedback separately, naming the full
SHA; use COMMENT alone when approval limits prevent approval.

Immediately before approval, recheck the head with
`gh pr view NUMBER -R OWNER/REPO --json headRefOid`. If changed, get independent
review of the new SHA. Binding pins the review, not the current head; concurrent
pushes remain possible and stale-review protection still matters.

Inspect the response and confirm remote `state=APPROVED` and `commit_id=FULL_SHA`:

```sh
gh api --paginate repos/OWNER/REPO/pulls/NUMBER/reviews
```

Match the bot's returned review ID and author. On uncertain delivery, verify with
that read; if still unknown, report uncertainty without claiming or resubmitting approval.

Review files must be regular, single-link files no larger than 1 MiB, reached
without symlinks or nested mounts. Keep them below the project root or in an
unpredictable `/tmp/public` path. Relative paths resolve from the invocation
directory; use an absolute path when crossing between those roots.

## Reactions and line comments

### Notification acknowledgement

The coordinator acknowledges independently authenticated notifications as soon as
it verifies the exact target, even when authorization fails. Use `+1` for warranted
action, `-1` for policy denial, or `eyes` if not yet clear. Send one raw `content`
field on the exact supported object. No fallback reaction or comment for submitted
reviews or other unsupported objects. Acknowledgement is not authorization,
completion, or substantive feedback.

```sh
gh api -X POST repos/OWNER/REPO/issues/NUMBER/reactions -f content='+1'
gh api -X POST repos/OWNER/REPO/issues/comments/COMMENT_ID/reactions -f content=eyes
gh api -X POST repos/OWNER/REPO/pulls/comments/COMMENT_ID/reactions -f content=heart
```

Supported reactions are `+1`, `-1`, `laugh`, `confused`, `heart`, `hooray`,
`rocket`, and `eyes`.

### Line comments

For a finding on one exact diff line:

```sh
gh api -X POST repos/OWNER/REPO/pulls/PR/comments \
  -f body='Concise finding and requested fix.' \
  -f commit_id=FULL_40_LOWERCASE_HEX_SHA \
  -f path=REPOSITORY_RELATIVE_PATH \
  -f line=POSITIVE_LINE \
  -f side=RIGHT
```

Use `LEFT` for a deletion and `RIGHT` for an addition or context line. Supply
exactly those five unique raw fields. Do not use `-F`, ranges, file-level comments,
deprecated positions, pending-review arrays, or raw whole-review API writes.

## Boundaries and troubleshooting

Permanent deletion, changing an existing pull request's base or
head, moderation, administration, review dismissal, auth/config access, and
arbitrary API calls are denied. Branch publication uses the configured Git SSH
remote rather than this broker. Fast-forward updates to another author's exact
branch require an authorized maintainer's explicit request for that branch and
change, or the narrow author authorization in `fedimint-bot-pr-branch-rewrite`.
Before any non-fast-forward update, load and follow that skill; a verified
repository maintainer may explicitly authorize
rewriting another author's exact PR without author consent. Otherwise publish a
new non-conflicting `tau/` head only when that delivery is within the authorized
scope.
If the requested update is unsupported, report the concrete blocker.

Ground blockers in the installed grammar, applicable configuration, or observed
broker, Git SSH, permission, or configuration failures. No forbidden probes or
repeated failed mutations.
