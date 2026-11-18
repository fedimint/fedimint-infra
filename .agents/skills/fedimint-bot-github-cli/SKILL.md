---
name: fedimint-bot-github-cli
description: Use for GitHub reads, comments, reviews, issue or pull-request updates, milestones, public gists, reactions, pull-request creation and merging, fork workflow-run approval, and approved-PR CI flake retries in the Fedimint bot sandbox.
user-invocable: true
advertise: true
---

# GitHub CLI in the Fedimint bot sandbox

Use `gh` for GitHub interaction. A sandbox broker intercepts the installed
command and accepts only a bounded grammar for reads and writes. Use the
documented forms below. If a form is denied, do not try another
client, credential path, raw API variant, reordered flags, mutation `--help`, or
another executable path.

Use explicit `-R OWNER/REPO` for repository CLI commands and the exact repository
in API paths. Inspect current state before mutation, perform one mutation at a
time, and verify remote state afterward. After an ambiguous result, inspect remote
state before deciding whether a retry is safe; never retry blindly.

## Bounded reads

Run `gh` from `/home/tau-fedimint/fedimint`, not a project subcheckout: project
shells can supply a different `gh` that does not use the sandbox broker.

For PR inspection, request only the JSON fields you need for the task. This
metadata recipe avoids organization-dependent fields such as `reviewRequests`;
default PR views and `--comments` can request fields that require unavailable
`read:org` scope.

```sh
gh pr view NUMBER -R OWNER/REPO --json number,state,isDraft,author,headRefOid,headRefName,baseRefName,title,body,files
gh pr diff NUMBER -R OWNER/REPO
gh api repos/OWNER/REPO/pulls/NUMBER
gh api repos/OWNER/REPO/pulls/NUMBER/files --paginate
gh api --paginate repos/OWNER/REPO/pulls/NUMBER/reviews
gh api repos/OWNER/REPO/issues/comments/COMMENT_ID
```

Use the `files` metadata or paginated PR-files response to identify changed
paths, and the full PR diff to inspect changes. Filter saved output locally
when needed; `gh pr diff --stat` and diff pathspecs are unsupported.

These recipes do not authorize arbitrary API reads. Repository
`commits`, `contents`, and `compare` endpoints and reaction-list GETs are
unsupported. Repository-wide commit reads are unsupported, unlike the bounded
PR-scoped commits collection documented in `fedimint-bot-weekly-dev-summary`.
If a required read is unavailable,
report the blocker rather than trying endpoint variants or another client.

## Team membership reads

The broker permits read-only team lookups only in the `fedimint` organization:

```sh
gh api orgs/fedimint/teams/lightning/members --paginate
gh api orgs/fedimint/teams/lightning/memberships/USERNAME
```

Substitute the team slug and username. Only an `active` membership
confirms current membership; `pending` does not. A 404, hidden team, inaccessible
roster, or any error means unknown, not nonmembership. Do not infer
absence from an incomplete roster. Membership facts do not grant authority
beyond the applicable authorization policy.

The existing classic action token needs `read:org` and visibility into the team.
Enabling these routes does not add token permissions.
Report missing access; do not change credentials or try another client.

## Public gists

The broker permits only public gists owned by `fedimint-tau` (`332691140`) and
verifies the account on every call. The existing classic action token retains its
broader account-scoped authority; this public-only route does not make the token
repository-scoped. Other scopes do not enable Projects, Discussions, audit-log,
key, hook, or administrative commands.

Publication requires an explicit request and safe content: no secrets, raw private
logs, or private conversations in filenames, descriptions, or files. Gist edits
retain history; replacing content does not retract it.

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

For PR CI or Merge Queue failures, inspect the failed attempt with
`gh run view NUMERIC_RUN -R OWNER/REPO --attempt ATTEMPT --log-failed`. Use trusted
run and PR metadata to tie the run to each affected open PR's exact current head.
Require an effective GitHub APPROVE review bound to each of those SHAs; a comment,
an independent PASS, or fork workflow-run approval is not PR approval.

Only retry a completed failed run when evidence suggests a flake and the failed
jobs and their dependents are safe to re-execute. Reserve the coordinator's
durable per-PR budget, then recheck the run, attempt, affected heads, and approvals
immediately before `gh run rerun NUMERIC_RUN -R OWNER/REPO --failed`. The broker
allows only this rerun form; the default credential still needs Actions write.
Verify the attempt afterward. Preserve the original failure evidence and continue
the investigation even if the retry passes or is denied.

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

Merge only when a verified repository maintainer explicitly requests or agrees to
merge the exact PR in a GitHub comment. Verify their native `write` or `admin`
permission on the target repository using fresh trusted delivery facts or `github_user_context`; team membership, a bot
review, and CI success alone do not authorize merging.

Read current PR state and checks. Confirm the request still covers the current
head, then use the inspected full lowercase head SHA:

```sh
gh pr merge NUMBER -R OWNER/REPO --match-head-commit FULL_SHA
gh pr merge NUMBER -R OWNER/REPO --squash --match-head-commit FULL_SHA
```

The first form uses the repository's merge queue when required; for a direct
merge, select one repository-supported method (`--merge`, `--squash`, or
`--rebase`). Never bypass protections, use admin flags, or weaken checks.
`--match-head-commit` provides an atomic head check for direct merges, but queue
and auto-merge paths do not provide the same guarantee. Do not use a queue path
when the authorization requires an exact-SHA guarantee. Recheck remote state after the
operation and report whether it merged, queued, or enabled auto-merge; command
success alone does not mean merged. Stop on a changed head or protection failure.

## Fork workflow-run approval

This procedure approves a fork PR workflow run, not a PR review, deployment, or
environment approval. After an independent PASS on the PR's exact current head, automatically
approve needed gated runs for that revision without a separate maintainer request.
PR activity or bot-access membership alone is not a passing review. Include the
passing review, exact SHA, and target in any delegation.

Before approval, inspect the run's repository, event, workflow, and head SHA.
Use trusted metadata to associate it with the reviewed PR and current head. An
empty `pull_requests` list is not a veto; correlate repository, fork, branch, SHA,
and event/workflow metadata instead. Confirm the run actually awaits fork workflow
approval: `completed` with `action_required` alone does not establish that gate.
Review all code that will execute, including workflow changes and scripts, for
safe execution on the target runners. If safety, gate eligibility, or the
run-to-head association is uncertain, stop and report the blocker.

```sh
gh api repos/OWNER/REPO/actions/runs/RUN_ID
gh api --method POST repos/OWNER/REPO/actions/runs/RUN_ID/approve
```

Use one concrete numeric run ID, with no payload or extra API options. Recheck the
run and PR immediately before approval; this endpoint has no expected-head
parameter. Inspect the run state afterward before reporting success or retrying
an ambiguous result. This capability does not authorize deployment approvals,
workflow dispatch, broader reruns, or changes to Actions settings.

## SHA-bound approval and review forms

Publish formal reviews as COMMENT, never REQUEST_CHANGES. APPROVE requires an
authenticated target-repository maintainer's explicit request to approve that PR,
not merely `fedimint/bot-access` membership. Require fresh
membership before publishing; independent PASS and a pinned SHA do not expand
the requester's authority. The formal approval procedure below applies only
when separate authority and all approval limits permit it.

Formal reviews use:

```sh
gh pr review NUMBER -R OWNER/REPO --comment --body-file FILE
gh pr review NUMBER -R OWNER/REPO --approve --commit-id FULL_SHA
```

Formally approve eligible changes only after independent PASS for the exact
inspected SHA and satisfaction of all main-prompt approval limits. `FULL_SHA` is
that full 40-character lowercase hexadecimal commit. This broker-specific form submits
`event=APPROVE` and `commit_id=FULL_SHA`; it accepts no body or extra flags.
Never use unpinned approval or a raw API write. Publish substantive feedback
separately, naming the full inspected SHA; use comment-only feedback when approval
limits prevent approval.

Immediately before approval, recheck the head with
`gh pr view NUMBER -R OWNER/REPO --json headRefOid`. If it changed, obtain independent
review of the new SHA first. Binding prevents approval attaching to a different
unreviewed commit; it is not an atomic current-head comparison and does not prevent
concurrent pushes or replace stale-review protection.

Verify the submitted review's `state` is `APPROVED` and `commit_id` equals the
inspected SHA. Inspect the returned review and confirm remote state using:

```sh
gh api --paginate repos/OWNER/REPO/pulls/NUMBER/reviews
```

Identify the bot's review by its returned review ID and author, not another
reviewer's approval. After an ambiguous result, use that read before retrying;
if delivery cannot be established, preserve the uncertainty and do not claim
approval or blindly submit a duplicate.

Review files must be regular, single-link files no larger than 1 MiB, reached
without symlinks or nested mounts. Keep them below the project root or in an
unpredictable `/tmp/public` path. Relative paths resolve from the invocation
directory; use an absolute path when crossing between those roots.

## Reactions and line comments

### Notification acknowledgement

The coordinator acknowledges each independently authenticated notification as
soon as it verifies the exact target, including requests denied authorization.
Do not wait for disposition or task completion.
React on the exact delivered object only if it has a supported form below.
Use `+1` when action is warranted and `-1` when policy prevents action.
If no better reaction applies yet, use `eyes` as an “I've seen it” placeholder.
Send each reaction with one raw `content` field. Submitted reviews
(distinct from inline review comments) and other unsupported objects receive no
reaction. Do not substitute the PR root or create an acknowledgement comment.
A reaction neither claims completion nor authorizes work; substantive responses
remain a separate obligation.

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

Before reporting a blocker, inspect installed skill guidance and applicable
configuration or available state. Installed grammar establishing an unsupported
operation is sufficient evidence; otherwise use an observed broker, Git SSH,
permission, or configuration failure. Do not invent a denial, probe forbidden commands,
or repeat failed mutations in a loop.
