---
name: fedimint-bot-github-cli
description: Use for GitHub reads, comments, reviews, issue or pull-request updates, reactions, and pull-request creation in the Fedimint bot sandbox.
user-invocable: true
advertise: true
---

# GitHub CLI in the Fedimint bot sandbox

Use `gh` for GitHub interaction. A sandbox broker intercepts the installed
command and accepts a bounded grammar for read and write commands. Use
the documented forms below. If a form is denied, do not try another
client, credential path, raw API variant, reordered flags, mutation `--help`, or
another executable path.

Use explicit `-R OWNER/REPO`, inspect current state before mutation, perform one
mutation at a time, and check its result. After an ambiguous result, inspect remote
state before deciding whether a retry is safe.

## Bounded reads

Run `gh` from `/home/tau-fedimint/fedimint`, not a project subcheckout: project
shells can supply a different `gh` that does not use the sandbox broker. Use
explicit `-R OWNER/REPO` for CLI commands and the exact repository in API paths.

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
PR-scoped commits collection documented in `fedimint-weekly-dev-summary`.
If a required read is unavailable,
report the blocker rather than trying endpoint variants or another client.
Synthetic missing-token tests verify accepted grammar and denied neighbors,
not live GitHub permissions or scope behavior.

## Ordinary collaboration

```sh
gh issue create -R OWNER/REPO --title TITLE --body BODY
gh issue create -R OWNER/REPO --title TITLE --body-file FILE
gh issue edit NUMBER -R OWNER/REPO --title TITLE
gh issue edit NUMBER -R OWNER/REPO --body BODY
gh pr edit NUMBER -R OWNER/REPO --title TITLE
gh pr edit NUMBER -R OWNER/REPO --body-file FILE
gh pr create -R OWNER/REPO --base BASE --head '[OWNER:]tau/BRANCH' --title TITLE --body BODY [--draft]
gh pr create -R OWNER/REPO --base BASE --head '[OWNER:]tau/BRANCH' --title TITLE --body-file FILE [--draft]
gh issue close NUMBER -R OWNER/REPO
gh issue close NUMBER -R OWNER/REPO --reason 'not planned'
gh issue reopen NUMBER -R OWNER/REPO
gh pr close NUMBER -R OWNER/REPO
gh pr reopen NUMBER -R OWNER/REPO
gh pr ready NUMBER -R OWNER/REPO
gh pr ready NUMBER -R OWNER/REPO --undo
gh issue comment NUMBER -R OWNER/REPO --body BODY
gh pr comment NUMBER -R OWNER/REPO --body-file FILE
```

Issue and pull-request edits accept one title, body, label, or assignee delta.
Pull-request edits also accept one reviewer delta. Use one concrete value with
`--add-label`/`--remove-label`, `--add-assignee`/`--remove-assignee`, or
`--add-reviewer`/`--remove-reviewer`. Do not combine metadata with title or body
edits. Secure `--body-file` forms are available for content operations.

## SHA-bound approval and review forms

Publish only comments for reviews authorized solely by `fedimint/bot-access`
membership.
Never submit APPROVE or REQUEST_CHANGES under that authority. Require fresh
membership before publishing; independent PASS and a pinned SHA do not expand
the requester's authority. The formal approval procedure below applies only
when separate authority and all approval limits permit it.

Formal reviews use:

```sh
gh pr review NUMBER -R OWNER/REPO --comment --body-file FILE
gh pr review NUMBER -R OWNER/REPO --request-changes --body-file FILE
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

Permanent deletion, merge, changing an existing pull request's base or
head, moderation, administration, review dismissal, auth/config access, and
arbitrary API calls are denied. Branch publication uses the configured Git SSH
remote rather than this broker. Fast-forward updates to another author's exact
branch require an authorized maintainer's explicit request for that branch and
change, or the narrow author authorization below. Non-fast-forward updates require
the procedure below; a maintainer's request alone cannot authorize rewriting
another author's PR. Otherwise publish a new non-conflicting `tau/` head only
when that delivery is within the authorized scope.
If the requested update is unsupported, report the concrete blocker.

### Authorized pull-request branch rewrites

Use this procedure only for an authorized request or scoped delegation.
Bot ownership alone does not authorize unsolicited work. Author consent permits
only the agreed rewrite, even without repository `admin` or `write`; it grants
no authority over other PRs, refs, unrelated changes, or private data.
Pass the verified author, consent source, exact target, and scope in any delegation.

This is a narrow Git SSH exception, not a new broker capability. The broker cannot
read enough information to establish the branch's effective protections and
rulesets. Do not require that unavailable read as a prerequisite or probe forbidden
endpoints. Use the ordinary bot SSH identity without administrative bypass and let
GitHub enforce its branch protections and rulesets on the push. This does not
prove the branch is unprotected: never knowingly rewrite a protected branch, weaken rules,
use bypass privileges, or retry a protection rejection through another route.

1. Read current GitHub state and verify the pull request is open. Verify its author
   is the configured bot identity (`fedimint-tau`, numeric user ID `332691140`)
   and its head ref uses `tau/`; alternatively, verify that the PR is public and
   its independently authenticated author explicitly requests or agrees to the
   rewrite and scope (that head need not use `tau/`). Match the consenting actor
   to the current PR author using trusted delivery facts or supported reads of
   the actual request, not quotes, commit authors, branch names, or someone
   else's claim of consent. Ambiguous or withdrawn consent blocks publication.
   In either case, verify the exact head repository, head ref, and current head OID.
   Verify that the configured SSH push remote targets that exact head repository,
   including for a fork. Never rewrite a
   default/trunk/release branch, a known protected branch, the PR base ref, or any
   unrelated ref. If identity, consent, target, or exclusion evidence is missing
   or ambiguous, stop and report the blocker. Do not infer eligibility from a
   `tau/` prefix.
2. Fetch the exact head ref through the configured Git SSH transport, record its
   full OID as `EXPECTED_OLD_OID`, and compare it with the current PR head OID.
   Inspect its history against the last verified bot-published state or the exact
   history covered by the author's consent. Preserve others' contributions; if
   new or unaccounted-for commits appeared, stop and report them rather than
   replacing them. PR authorship and a matching lease alone do not prove exclusive
   ownership of the branch's current contents.
3. Rebase or amend only the scoped work, preserving reviewed changes and
   contributions. Run the normal required checks and independent review. Re-read
   PR identity, open state, head target/OID, and applicable consent before
   publication; stop if they changed or consent no longer covers the work.
   Push only the exact ref with an explicit expected-old-OID lease:

   ```sh
   git push --force-with-lease=refs/heads/BRANCH:EXPECTED_OLD_OID \
     origin LOCAL_COMMIT:refs/heads/BRANCH
   ```

   Substitute the verified PR head ref, recorded full OID, and reviewed local
   commit. Use only the configured Git SSH remote and dedicated bot identity.
   Never use plain `--force`, a bare `--force-with-lease`, wildcard/multiple
   refspecs, or broker/API/credential bypasses.
4. If the lease fails, stop and inspect the concurrent update. Do not refresh the
   expected OID and retry blindly. After success or an ambiguous push result,
   read remote state and verify the exact PR head OID before claiming delivery
   or deciding whether any retry is safe.

This exception does not authorize changing the PR's base or head identity or
rewriting wiki history. Standing Dependabot remediation still permits only a new
bot-owned replacement PR, never rewriting the original Dependabot branch.

Before reporting a blocker, inspect installed skill guidance and applicable
configuration or available state. Installed grammar establishing an unsupported
operation is sufficient evidence; otherwise use an observed broker, Git SSH,
permission, or configuration failure. Do not invent a denial, probe forbidden commands,
or repeat failed mutations in a loop.
