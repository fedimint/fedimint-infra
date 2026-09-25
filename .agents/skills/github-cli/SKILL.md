---
name: github-cli
description: Use for GitHub reads, comments, reviews, issue or pull-request updates, reactions, and pull-request creation in the Fedimint bot sandbox.
user-invocable: true
advertise: true
---

# GitHub CLI in the Fedimint bot sandbox

Use `gh` for GitHub interaction. The installed command is intercepted by a
sandbox broker with a deliberately bounded grammar. Read normally, but use only
the documented forms below for mutations. If a form is denied, do not try another
client, credential path, raw API variant, reordered flags, mutation `--help`, or
another executable path.

Use explicit `-R OWNER/REPO`, inspect current state before mutation, perform one
mutation at a time, and check its result. After an ambiguous result, inspect remote
state before deciding whether a retry is safe.

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

Formal reviews use:

```sh
gh pr review NUMBER -R OWNER/REPO --comment --body-file FILE
gh pr review NUMBER -R OWNER/REPO --request-changes --body-file FILE
gh pr review NUMBER -R OWNER/REPO --approve
```

Review files must be regular, single-link files no larger than 1 MiB, reached
without symlinks or nested mounts. Keep them below the project root or in an
unpredictable `/tmp/public` path. Relative paths resolve from the invocation
directory; use an absolute path when crossing between those roots.

## Reactions and line comments

React on the exact delivered object with one raw `content` field:

```sh
gh api -X POST repos/OWNER/REPO/issues/NUMBER/reactions -f content='+1'
gh api -X POST repos/OWNER/REPO/issues/comments/COMMENT_ID/reactions -f content=eyes
gh api -X POST repos/OWNER/REPO/pulls/comments/COMMENT_ID/reactions -f content=heart
```

Supported reactions are `+1`, `-1`, `laugh`, `confused`, `heart`, `hooray`,
`rocket`, and `eyes`.

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

Permanent deletion, merge, force-push, changing an existing pull request's base or
head, moderation, administration, review dismissal, auth/config access, and
arbitrary API calls are denied. Branch publication uses the configured Git SSH
remote rather than this broker. Update another author's exact branch only when an
authorized maintainer explicitly requests that branch and change; otherwise publish
a new non-conflicting `tau/` head. If the requested update requires force-push or is
unsupported, report the concrete blocker.

Before reporting a blocker, inspect installed skill guidance, broker output, and
current GitHub state. Base the blocker on an observed broker, Git SSH, permission,
or configuration failure. Do not infer a denial, probe through forbidden commands,
or repeat failed mutations in a loop.
