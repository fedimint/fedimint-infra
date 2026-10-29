# Tau Fedimint bot

The bot runs as `tau-fedimint` on runner-01, in the user systemd service
`tau-fedimint-bot.service`. It handles GitHub work, admitted Discord requests,
and scheduled maintenance through one coordinator.

## Where to look

| Concern | Source |
| --- | --- |
| Service, sandbox, role prompts, schedules, and options | [`modules/tau-fedimint-bot.nix`](../modules/tau-fedimint-bot.nix) |
| Enabled runner configuration and package pins | [`flake.nix`](../flake.nix), [`flake.lock`](../flake.lock) |
| Bot task instructions | [`.agents/skills`](../.agents/skills) |
| Local script and real sandbox checks | [`tests/tau-fedimint-bot.nix`](../tests/tau-fedimint-bot.nix) |
| Secret recipients and encrypted sources | [`secrets.nix`](../secrets.nix), `secrets/` |

## Operate the existing bot

Use the [operator skill](../.agents/skills/fedimint-tau-bot/SKILL.md) to discover
the current runtime and send an authorized request to its existing coordinator.
Use the [debugging skill](../.agents/skills/fedimint-tau-bot-papercuts-debugging/SKILL.md)
for read-only triage and post-deployment checks.

Inspect the existing conversation for completion before resending a `tau message`.
A timeout does not cancel accepted work. Use read-only checks to assess health;
a live prompt starts work.

Every service start clears the fixed `tau-fedimint-bot` session and starts a fresh
coordinator. Repositories, Clank, and other persistent state survive; the
coordinator recovers its queue from them. Coordinate deployments around active
work, since activation can restart the service and interrupt agents and tools.

The installed `tau-fedimint-sandbox` wrapper supplies the service's isolate
profile without running the launcher. Even `dev print-prompt` initializes
extensions. Follow the operator skill to inspect prompts without starting a
second notifier.

## Credentials and containment

The bot's writable project root is `/home/tau-fedimint/fedimint`. Core, SDK, and
infra work reuse their main checkouts there, with one implementing engineer per
repository under an update lock. Clank stores durable tasks outside the checkout;
it is recovery state, not a source of authority.

The sandbox intercepts `gh` through a host broker. The action token stays outside
the sandbox; a dedicated SSH agent supplies Git access. Notification and Discord
credentials are separate agenix secrets. See
[`fedimint-bot-github-cli`](../.agents/skills/fedimint-bot-github-cli/SKILL.md)
for supported commands, body-file imports, and branch publication.

Isolate guards against accidental agent actions, not hostile code. It shares the
host network and exposes the configured runtime, state, and agent socket. Browser
CDP uses unauthenticated host loopback; this is accepted for this trusted
single-user deployment, not a safe default for a shared host.

Use `mktemp` to allocate unpredictable paths in the shared, non-listable
`/tmp/public` dropbox and pass exact paths to delegates. Keep secrets and raw
private traces in private state. The module protects isolate's backing `public`
mountpoint from tmpfiles aging.
To diagnose missing shared files in `/tmp/public`, inspect
the **running inner daemon's** mount namespace; a fresh sandbox can work while
the old daemon has lost its bind. A restart restores the bind but clears the
session.

## GitHub and Discord

GitHub ingress watches core, SDK, and infra. It is notification-triggered, not a
complete activity feed. Comments require a direct bot mention; review requests
must target the bot. Repository watch subscriptions persist after the notifier
stops. Notification admission and permission lookup are separate from outbound
broker authority.

For task policy, use
[`fedimint-maintainer-requests`](../.agents/skills/fedimint-maintainer-requests/SKILL.md)
and [`fedimint-pull-request-review`](../.agents/skills/fedimint-pull-request-review/SKILL.md).
Write-capable infra requests require native `write` or `admin` on **infra itself**. The
historical-contributor helper is not a substitute for that permission.
Repository access also does not prove that each dedicated token selects the
repository; diagnose actual credential denials before changing scopes.

### Limited bot-access membership

The notifier admits notifications from members of `fedimint/bot-access` (numeric
team ID `19107422`) without changing repository permissions or granting general
organization access to the shell broker. It refreshes the full team roster at
startup and about every four hours. Admission and authenticated identity context
use the same numeric-ID-bound
roster; login names and notification admission alone do not authorize work.
The numeric pin prevents a deleted and recreated team from inheriting this
authority. GitHub's team-member listing includes members of child teams; those
inherited members receive the same limited authority.

Team facts expire four hours after the start of the successful refresh. Failed
refreshes do not extend that deadline. Removing a member can therefore take up to
about four hours to revoke team-only authority. After expiry, do not perform
team-only work if refreshes are unavailable, fail, or remain incomplete; wait until
a complete refresh succeeds. Previously delivered facts, queued tasks, and
delegated work do not extend membership.
The coordinator obtains fresh context before continuing or publishing after expiry.
Separately verified maintainers retain their existing authority if team lookup fails.

Fresh team membership permits public read-only assistance, automatic review of
the member's newly opened public PR, and explicit review requests across core,
SDK, and infra. Reply on the originating public issue/PR and publish review
findings as comments, never formal approvals or change requests. Team membership
does not authorize source/history changes, untrusted code execution, PR creation,
merges, issue/label/admin changes, private-data access, deployment, or policy
changes. Maintainer permissions take precedence. Existing mention, direct-review,
draft, independent-review, SHA, and consensus rules still apply, as do the narrow
Dependabot and authenticated-PR-author exceptions.

Maintainer admission still comes from GitHub's effective repository collaborator
permissions plus the existing configured numeric-ID exception. Request
authorization separately checks native `write` or `admin` (on infra itself for
infra writes); there is no new editable maintainer list in Tau's UI.
Manage the limited roster in the GitHub organization's `bot-access` team instead.
That team is not a substitute for repository collaborator access.

Discord admits personal mentions from configured human maintainers in one
private channel. Admission permits safe read-only assistance and a reply; it
does not authorize source or GitHub mutations. Display names and aliases are
presentation, not identity.

The coordinator sends configured announcements and alerts needing external help
to Discord; keep ordinary GitHub updates on GitHub. Use full issue/PR URLs in
Discord. Sends suppress mentions, and provider acceptance does not imply that a
maintainer has read the message.

Provision credentials with `just agenix-edit`, using the recipient policy in
`secrets.nix`. Discord needs independent token and stable identity secrets.
Offline checks do not prove live channel access.

## Scheduled work

Read schedules and delivery prompts in the module; use these skills for task
instructions:

| Task | Instructions |
| --- | --- |
| Weekly development summary | [`fedimint-weekly-dev-summary`](../.agents/skills/fedimint-weekly-dev-summary/SKILL.md) |
| Own-PR grooming | [`self-pr-grooming`](../.agents/skills/self-pr-grooming/SKILL.md) |
| Papercut self-improvement | [`fedimint-bot-self-improvement`](../.agents/skills/fedimint-bot-self-improvement/SKILL.md) |
| Working-directory cleanup | Module's cleanup prompt |

Timers deliver to the existing bot; they neither start it nor wait for task
completion. Papercut grooming is persistent and catches up missed firings when
the user manager resumes; the other timers are nonpersistent. Reconcile delivery
failures and uncertain sends before retrying.

The weekly summary covers the preceding **184 hours**, not a calendar week.
Its overlapping window is intentional. The summary skill owns page naming,
reruns, publication, and announcement details.

Only the coordinator has papercut history tools. Follow the self-improvement
skill to archive the exact reviewed generation and handle concurrent arrivals.
For operator-led grooming, use the
[operator grooming skill](../.agents/skills/fedimint-tau-bot-papercuts-grooming/SKILL.md).

Cleanup waits for active work and builds to finish, preserves unfinished source,
and removes disposable output across the project root. It is an agent workflow,
not an automatic deletion service or enforced task barrier.

## Development and validation

Shell commands use `direnv-dpc exec .` in the agent's effective workdir. Inspect
each checkout's `.envrc`, then run `direnv-dpc allow` there as the bot account.
Changed content needs renewed approval. An unapproved file warns and runs the
command without loading that environment; deployment does not approve it.

The service packages `agent-browser` and Chromium with Chromium's sandbox enabled.
Use a distinct `--session` per task and close it afterward.

For changes to this integration, run the flake's bot check and build runner-01:

```console
nix build .#checks.x86_64-linux.tau-fedimint-bot-config
nix build .#nixosConfigurations.runner-01.config.system.build.toplevel
```

The check exercises local scripts, startup preservation, and real sandbox,
browser, SSH, scratch-cleanup, and broker file-import behavior. It also runs the
real pinned GitHub notifier's protocol14 handshake and generated
notifications-enabled config with synthetic credentials in a network-isolated
Nix build sandbox, stopping at startup ready to verify protocol/config
compatibility. It does not verify live readiness, credentials, or external
delivery. After an authorized deployment
through `just apply-runner "01"`, follow the debugging skill for live checks.

When upgrading Tau's persistent-state format, stop writers and retain a
consistent private backup of the **complete** state, including journals,
artifacts, extension state, and repository/Clank recovery data. Retain the old
closure too. A NixOS rollback alone cannot undo a data-format upgrade or external
side effects; restore compatible state and reconcile those effects.
