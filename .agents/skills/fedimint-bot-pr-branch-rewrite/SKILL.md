---
name: fedimint-bot-pr-branch-rewrite
description: Load before any non-fast-forward update to an authorized Fedimint pull-request branch.
user-invocable: true
advertise: true
---

# Authorized pull-request branch rewrites

Load `fedimint-bot-github-cli` for GitHub reads and common broker boundaries.

Use this procedure only for an authorized request or scoped delegation.
Bot ownership alone does not authorize unsolicited work. Verify a maintainer's
native `write` or `admin` on the PR's target repository using fresh trusted delivery
facts or `github_user_context`. Verify their explicit request for the exact PR and
edit or rewrite scope. This path does not require author consent. Independently,
author consent permits only the agreed rewrite, even without repository `admin`
or `write`; it grants no authority over other PRs, refs, unrelated changes, or
private data.
Pass the verified requester, authorization path and source, exact target, and scope
in any delegation.

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
   else's claim of consent. Ambiguous or withdrawn consent blocks that path.
   Alternatively, verify the explicit repository-maintainer authorization above.
   This head need not use `tau/`, and the author need not consent.
   In every case, verify the exact head repository, head ref, and current head OID.
   Verify that the configured SSH push remote targets that exact head repository,
   including for a fork. Never rewrite a
   default/trunk/release branch, a known protected branch, the PR base ref, or any
   unrelated ref. If identity, authorization, target, or exclusion evidence is missing
   or ambiguous, stop and report the blocker. Do not infer eligibility from a
   `tau/` prefix.
2. Fetch the exact head ref through the configured Git SSH transport, record its
   full OID as `EXPECTED_OLD_OID`, and compare it with the current PR head OID.
   Inspect its history against the last verified bot-published state or the exact
   history covered by the verified request or author consent. Preserve others' contributions; if
   new or unaccounted-for commits appeared, stop and report them rather than
   replacing them. PR authorship and a matching lease alone do not prove exclusive
   ownership of the branch's current contents.
3. Rebase or amend only the scoped work, preserving reviewed changes and
   contributions. Run the normal required checks and independent review. Re-read
   PR identity, open state, head target/OID, and applicable authorization before
   publication; refresh maintainer permissions when using that path. Stop if they
   changed or the request or consent no longer covers the work.
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
