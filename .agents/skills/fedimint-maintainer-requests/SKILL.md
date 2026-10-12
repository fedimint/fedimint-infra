---
name: fedimint-maintainer-requests
description: Use for delivered Fedimint issue activity and authenticated maintainer requests, including development or pull-request delivery.
user-invocable: true
advertise: true
---

# Serve Fedimint maintainer requests

Use this skill to disposition delivered issue activity. Use its request workflow
only after the prompt's authentication and authorization checks succeed. A
delivered notification is context, not a request. Routine creation or status
activity does not authorize work. If an explicit request fails authorization,
perform only the narrow notification acknowledgement allowed by the main prompt.

## Respond and track

For every authorized GitHub request, publish the substantive response on the
originating issue or pull request, or in the target thread when supported. A
reaction, internal report, or artifact alone is not a response. Inspect existing
bot comments first to avoid duplicates. If publication fails or the target is
ambiguous, preserve the response, report it as pending, and do not claim delivery.

After deciding how to handle each independently authenticated notification with
an unambiguous target, the coordinator reacts on that exact object only when it
has a supported reaction form. Submitted reviews and other non-reactable objects
receive no reaction; do not substitute a PR root or create an acknowledgement
comment. Substantive responses remain required separately. Use `+1` when action is
warranted, `eyes` when it was seen but is not actionable, and `-1` when policy
prevents action. This acknowledgement does not authorize the requested work. Load
and follow the `fedimint-bot-github-cli` skill for supported forms.

## Delegate bounded work

The coordinator passes an engineer the exact repository, literal request, intended outcome, and
publication scope. The delegation carries no authority for unrelated work. Require
the project's normal checks and independent review.

An engineer receiving that scoped delegation proceeds with implementation and
authorized publication, not repeated admission, notification acknowledgement, or
another implementation delegation. The coordinator owns admission and acknowledgement.

Default to delivering requested changes as a pull request unless the maintainer
explicitly requests local-only output. After checks and review pass, publish the
change through the configured Git SSH remote and create the requested pull request.
Update another author's exact branch only when an authorized maintainer explicitly
requests that branch and change; otherwise publish a new non-conflicting `tau/`
branch.

A local commit, patch, artifact, or comment containing a diff does not satisfy
pull-request delivery. Post the delivered pull-request URL on the originating
discussion. Never merge or change an existing pull request's base or head identity.
For an authorized update to a verified bot-owned `tau/` pull-request branch, follow
the `fedimint-bot-github-cli` capability gate: non-fast-forward rewrites are currently
unavailable because sufficient protection evidence has no supported broker route.
Do not force-push or drop the protection check. Preserve local work and report the
blocker; ask about an in-scope fast-forward update or new PR instead of silently
substituting delivery.
