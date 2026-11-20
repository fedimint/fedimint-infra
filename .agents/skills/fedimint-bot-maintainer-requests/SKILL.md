---
name: fedimint-bot-maintainer-requests
description: Use for delivered Fedimint issue activity and authorized requests, including limited bot-access assistance and maintainer development requests.
user-invocable: true
advertise: true
---

# Serve authorized Fedimint requests

Handle delivered issue activity here, but use the request workflow only after
the main prompt's authorization checks, including its exact-PR author consent
path. Delivery alone authorizes no work. On denial, only acknowledge under
`fedimint-bot-github-cli`.

## Respond and track

For every authorized GitHub request, publish the substantive response on the
originating issue or pull request, or in the target thread when supported. A
reaction, internal report, or artifact alone is not a response. Inspect existing
bot comments first to avoid duplicates. If publication fails or the target is
ambiguous, preserve the response, report it as pending, and do not claim delivery.

## Delegate bounded work

The coordinator gives an engineer the exact repository, literal request, intended
outcome, and publication scope. The delegation carries no authority for unrelated
work. Require the project's normal checks and independent review.

An engineer receiving that scoped delegation implements and publishes the
authorized changes without repeating admission, acknowledging the notification,
or delegating implementation again. The coordinator handles admission and
acknowledgement.

For requests authorized only by fresh `fedimint/bot-access` membership, delegate
public read-only inspection or research, not implementation. Include the authenticated
numeric ID, team, observation and expiry times, exact target, and limited scope.
Reply substantively on that target. For review requests, follow
`fedimint-bot-pull-request-review` and publish only comments. Do not run untrusted code,
change source or history, create a PR, or treat a request to implement findings
as authorized. Stop at expiry and obtain fresh membership facts before continuing
or publishing. The development and PR-delivery instructions below apply only
when you have established separate write-capable authority.

After checks and review pass, deliver authorized development as a PR unless the
maintainer explicitly requests local-only output. Use the configured Git SSH
remote and `fedimint-bot-github-cli` for branch updates, PR creation, and any
separately authorized merge. Post the PR URL on the originating discussion.
A local commit, patch, artifact, or diff comment is not PR delivery. If blocked,
preserve local work and ask about an in-scope fast-forward update or new PR.
