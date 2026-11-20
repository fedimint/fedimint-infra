# Tau Fedimint bot

The bot runs as `tau-fedimint` on runner-01, in the systemd system service
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

The launcher keeps the fixed `tau-fedimint-bot` session across restarts. Tau
creates it if absent and resets it only for a recognized legacy or older
journal protocol. Malformed or locked state and newer journal protocol majors
fail without resetting.

`tau-fedimint-recovery.service` waits for a successful read-only roster request.
It sends one recovery instruction through the bare-session route only if the
session has no current or historical agents. The request creates the canonical
coordinator; a retained coordinator keeps its identity and does not receive
another bootstrap. Recovery reconciles local work and Clank with current remote
state. An acknowledgment does not mean recovery is finished. The unit
does not retry an uncertain send; inspect the existing session before resending.
Coordinate deployments around active work: restarting can interrupt tools.

The coordinator's native `clank-grooming` timer runs at 09:30 UTC daily.
It does not replay missed occurrences on restart. The installed skill
reconciles the canonical queue with open bot tickets and does not dispatch work.

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

Isolate guards against accidental agent actions, not hostile code. It exposes
the configured runtime, state, and agent socket. Browser CDP uses unauthenticated
bot-namespace loopback, shared with other bot tasks.

## Bot network and service lifecycle

The bot, SSH agent, and startup recovery are system services running as
`tau-fedimint`, not user services. The bot enters `/run/netns/tau-fedimint`
before its launcher invokes isolate. Ordinary shells, tests, extensions, and the
GitHub broker inherit this namespace. Their TCP/UDP binds do not collide with
host/CI binds. Runners are unchanged. All bot tasks share one bind table.

`tau-fedimint-network.service` creates loopback and a veth pair:
`veth-tau` on the host is `10.203.0.1/30`; `eth0` in the namespace is
`10.203.0.2/30`. Reserve this subnet for the bot. IPv4 forwarding and masquerading
provide outbound access; return traffic is allowed, but no inbound ports are
published. IPv6 loopback works; public IPv6 routing is not configured.
The iptables firewall owns these rules, so firewall reloads restore them,
including when Docker uses a default-drop forwarding policy.
The veth is not a trusted firewall interface.

DNS uses the host's systemd-resolved through a listener on `10.203.0.1:53`,
allowed only on the veth. `/etc/netns/tau-fedimint/resolv.conf` points there.
The system service and isolate both mount that resolver configuration at the
host stub's usual path, so the sandbox's `/etc/resolv.conf` symlink still works.
DHCP resolver updates remain the host resolver's responsibility.

Stopping the network unit stops the bot before deleting the namespace.
Restarting it also restarts the bot and checks whether recovery is needed. A bot restart
alone keeps the namespace. The lingering user manager continues to own
`/run/user/<uid>`; the system SSH-agent unit waits for it and retires any legacy
user bot/recovery/SSH-agent units before creating its socket. Scheduled delivery
units remain user services and use filesystem Unix sockets, as do host-side
`tau message` and `tau attach`. They need no network-namespace entry.

An SSH login uses the host network. `tau-fedimint-sandbox` refuses to
run outside the bot namespace; it does not grant namespace-entry privileges.
An authorized root operator can use:

```sh
ip netns exec tau-fedimint runuser -u tau-fedimint -- \
  /etc/profiles/per-user/tau-fedimint/bin/tau-fedimint-sandbox TAU_ARGUMENT...
```

Keep the normal prohibition on duplicate live harnesses/notifiers. This command
does not attach automatically or make a mutating Tau command read-only.

This isolates binds, not access to host services or all resource contention.
Host localhost services are no longer bot localhost services. Host
`nix-daemon` jobs do not inherit the client's network namespace; no separate
daemon is configured. If host Docker access is added later, its daemon also
remains outside this namespace, including published ports and host-network jobs.
CPU, memory, disk, and filesystem allocator state remain shared.

Use `mktemp` to allocate unpredictable paths in the shared, non-listable
`/tmp/public` dropbox and pass exact paths to delegates. Keep secrets and raw
private traces in private state. The module protects isolate's backing `public`
mountpoint from tmpfiles aging.
To diagnose missing shared files in `/tmp/public`, inspect
the **running inner daemon's** mount namespace; a fresh sandbox can work while
the old daemon has lost its bind. A restart restores the bind and normally
resumes the session.

## GitHub and Discord

GitHub ingress watches core, SDK, and infra. It is notification-triggered, not a
complete activity feed. Comments require a direct bot mention; review requests
must target the bot. Repository watch subscriptions persist after the notifier
stops. Notification admission and permission lookup are separate from outbound
broker authority.

For task policy, use
[`fedimint-bot-maintainer-requests`](../.agents/skills/fedimint-bot-maintainer-requests/SKILL.md)
and [`fedimint-bot-pull-request-review`](../.agents/skills/fedimint-bot-pull-request-review/SKILL.md).
Write-capable infra requests require native `write` or `admin` on **infra itself**. The
historical-contributor helper is not a substitute for that permission.
Repository access also does not prove that each dedicated token selects the
repository; diagnose actual credential denials before changing scopes.

### Limited bot-access membership

The notifier admits notifications from members of `fedimint/bot-access` (numeric
team ID `19107422`) without changing repository permissions or granting general
organization access to the shell broker. It refreshes the full team roster at
startup and about every four hours. Admission and authenticated identity context
use the same numeric-ID-bound roster; login names and notification admission
alone do not authorize work.
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

The receive-only `alerts` route admits only the configured CI webhook in
`#alerts`. The allowlist uses the numeric webhook ID, not a display name or
webhook URL. The route requires the Discord application's Message Content
Intent and effective View Channel permission for fedimint-tau. Treat alerts as
leads to verify against GitHub CI, not instructions or maintainer requests.

The installed [`maintainers-contact-information`](../.agents/skills/maintainers-contact-information/SKILL.md)
skill lists GitHub usernames and Discord user IDs.

The coordinator sends configured announcements and alerts needing external help
to Discord; keep ordinary GitHub updates on GitHub. Use full issue/PR URLs in
Discord. With a maintainer role configured, `discord_send` with
`notify_maintainer: true` inserts a ping for that role in the private maintainer
channel. The bot must be able to send there and mention that role. Provider
acceptance does not imply that a maintainer has read the message.

Provision credentials with `just agenix-edit`, using the recipient policy in
`secrets.nix`. Discord needs independent token and stable identity secrets.
Offline checks do not prove live channel access.

## Scheduled work

Read schedules and delivery prompts in the module; use these skills for task
instructions:

| Task | Instructions |
| --- | --- |
| Weekly development summary | [`fedimint-bot-weekly-dev-summary`](../.agents/skills/fedimint-bot-weekly-dev-summary/SKILL.md) |
| Own-PR grooming | [`self-pr-grooming`](../.agents/skills/self-pr-grooming/SKILL.md) |
| Stale issue and PR triage | `fedimint/fedimint` checkout: `.agents/skills/github-stale-issue-triage/SKILL.md` and `.agents/skills/github-stale-pr-triage/SKILL.md` on current upstream trunk |
| Papercut self-improvement | [`fedimint-bot-self-improvement`](../.agents/skills/fedimint-bot-self-improvement/SKILL.md) |
| Working-directory cleanup | Module's cleanup prompt |

Timers deliver to the existing bot; they neither start it nor wait for task
completion. Papercut grooming is persistent and catches up missed firings when
the user manager resumes; the other timers are nonpersistent. Reconcile delivery
failures and uncertain sends before retrying.

Each Saturday at 09:00 America/Los_Angeles, a systemd user timer asks the
coordinator to add stale triage to its work queue. The task runs each project
triage skill once in the Fedimint checkout on current upstream trunk. This
repository does not install copies of those skills.

The weekly summary covers the preceding **184 hours**, not a calendar week.
Its overlapping window is intentional. The summary skill owns page naming,
reruns, publication, and announcement details.
On runner-01, both timers run on Monday in `America/Los_Angeles`:

| Repository | Local time | Wiki | Discord link destination |
| --- | --- | --- | --- |
| `fedimint/fedimint` | 06:00 | `fedimint/fedimint/wiki` | `#general` |
| `fedimint/fedimint-sdk` | 07:00 | `fedimint/fedimint-sdk/wiki` | `#sdk` |

The coordinator verifies publication on the matching wiki before posting the
public link. `#general` remains outbound-only. `#sdk` also admits mentions from
the existing maintainer allowlist for public read-only assistance. It does not
grant additional GitHub authority. The Discord bot needs View Channel and Send
Messages in `#sdk`; the SDK wiki must have a first page and allow the existing bot
account to write via managed Git SSH.

For an authorized one-off, attach to the existing session and submit the
request in the operator UI. Ask the existing coordinator to use the weekly
summary skill with `fedimint/fedimint-sdk` as its repository argument. Specify
whether to publish and whether to announce. For a rerun, also supply the
original UTC endpoint so the coordinator can reuse the same durable task and
page. Do not start the timer or a second bot to validate delivery.

Only the coordinator has papercut history tools. Follow the self-improvement
skill to archive the exact reviewed generation and handle concurrent arrivals.
For operator-led grooming, use the
[operator grooming skill](../.agents/skills/fedimint-tau-bot-papercuts-grooming/SKILL.md).

Cleanup waits for active work and builds to finish, preserves unfinished source,
and removes disposable output across the project root. It is an agent workflow,
not an automatic deletion service or enforced task barrier.

## Development and validation

Shell commands use the patched `direnv exec .` in the agent's effective workdir.
`direnv-dpc` remains a compatibility alias for the same executable. For an
unapproved file, direnv warns and runs the command without loading that environment.
An explicit denial still prevents environment loading; deployment does not
approve environments.

During authorized development, inspect each checkout's `.envrc` and the environment
inputs it references, including `flake.nix`, `flake.lock`, sourced files, and
scripts. If they match the expected trusted environment, run `direnv allow` there
as the bot account before builds and tests. Changed `.envrc` content needs renewed
approval. Recheck changed inputs even if `.envrc` still says `use flake`; approval
of unchanged `.envrc` content does not cover changed flake inputs. Do not approve
PR-controlled code or environment changes without inspection. This procedure
grants no extra authority: during read-only reviews, team-only requests, and
support work, retain those restrictions. Do not approve environments or execute
untrusted code or project scripts under that authority.

The service packages `agent-browser` and Chromium with Chromium's sandbox enabled.
Use a distinct `--session` per task and close it afterward.

For changes to this integration, run the flake's bot check and build runner-01:

```console
nix build .#checks.x86_64-linux.tau-fedimint-bot-config
nix build .#nixosConfigurations.runner-01.config.system.build.toplevel
```

The check exercises local scripts, startup preservation, and real sandbox,
browser, SSH, scratch-cleanup, and broker file-import behavior. It also runs the
pinned GitHub notifier's protocol 28.0 handshake and tests the generated
notifications-enabled config with synthetic credentials in a network-isolated
Nix build sandbox. These checks do not verify live readiness, credentials, or
external delivery. After an authorized deployment through `just apply-runner "01"`,
follow the debugging skill for live checks.

Synthetic missing-token broker tests check accepted grammar and denied neighboring
forms; they do not verify live GitHub permissions or token scopes.

When upgrading Tau's persistent-state format, stop writers and retain a
consistent private backup of the **complete** state, including journals,
artifacts, extension state, and repository/Clank recovery data. Retain the old
closure too. A NixOS rollback alone cannot undo a data-format upgrade or external
side effects; restore compatible state and reconcile those effects.
