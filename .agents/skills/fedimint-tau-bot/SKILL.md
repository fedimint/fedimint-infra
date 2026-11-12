---
name: fedimint-tau-bot
description: >
  Access the deployed Fedimint Tau bot, discover its current runtime, and send
  authorized operator requests to its existing coordinator.
user-invocable: true
advertise: true
---

# Operate the Fedimint Tau bot

Use this skill to access the running bot and send authorized operator requests.
Discover the current coordinator with the helper below, then use
`tau message --wait-response` to contact it.
For diagnostics and post-deployment checks, use
[fedimint-tau-bot-papercuts-debugging](../fedimint-tau-bot-papercuts-debugging/SKILL.md).
These instructions grant no additional authority to the bot.

## Deployment policy: fix forward

This bot is not load-bearing. Accept breakage and downtime, deploy promptly,
and fix failures in the live runtime.

For an authorized deployment, follow the normal deployment path and run a brief
live check. Do not add tests, mock fixtures, or extra validation gates, or debug
tests to protect this bot's deployment. Follow required project workflow and
review without adding testing requirements.

Treat the current session as disposable: a normal service restart resets it.
Do not preserve or migrate the session, build backup or session-identity
machinery around it, or seek separate approval for a restart covered by
deployment authorization. Preserve durable repository and task data.

Start diagnostics read-only, but proceed with an authorized deployment and its
restart. Outside that authorization, get operator approval before restarting or
clearing the service. Do not start a duplicate Tau harness or
notifier, expose secrets or full provider captures, or manufacture external
activity as a deployment check. Keep security and secret protections in place.

## Discover the live runtime

Use an existing authorized operator connection to
`root@runner-01.dev.fedimint.org`. Determine the SSH invocation and
authentication from the current environment; do not prescribe a caller-local
socket, identity path, or setup workaround.

On the runner, invoke the installed Tau binary as the service account with its
effective runtime environment:

```sh
set -euo pipefail

tau_as_bot() {
  runuser -u tau-fedimint -- env \
    HOME=/home/tau-fedimint \
    XDG_CONFIG_HOME=/home/tau-fedimint/.config \
    XDG_STATE_HOME=/home/tau-fedimint/.local/state \
    XDG_RUNTIME_DIR=/run/user/$(id -u tau-fedimint) \
    /run/current-system/sw/bin/tau "$@"
}

id tau-fedimint
tau_as_bot --version
readlink /run/current-system
systemctl show \
  tau-fedimint-bot.service \
  -p ActiveState -p SubState -p MainPID -p ExecStart \
  -p FragmentPath -p ActiveEnterTimestamp
tau_as_bot session list --json
tau_as_bot agent list tau-fedimint-bot
```

This is a system service with `User=tau-fedimint`, not a user-manager unit. Re-run
these commands after every deployment. Discover the current numeric UID, binary,
session, and root coordinator agent ID; never hard-code an old PID, socket hash,
UID, or agent ID. A stable session name does not identify one daemon incarnation.

## Communicate with the existing coordinator

Sending input mutates the live conversation and requires explicit authorization.
Do not use it as a read-only health check.

Discover the current session and root coordinator ID as above. On the runner,
using the same `tau_as_bot` helper and authorized connection, substitute the
current ID and send one literal stdin message:

```sh
coordinator_id='FRESH_COORDINATOR_ID'
tau_as_bot message --wait-response "tau-fedimint-bot/@$coordinator_id" <<'REQUEST'
Describe your current task in one final reply via the message tool to the supplied one-shot reply address. Use no other tools and take no external actions.
REQUEST
```

The CLI uses local same-user IPC, so run it on the remote runner, not in the
operator's local Tau session. Exact session/agent targeting fails closed if the
target is absent and creates no sender agent or new session. Avoid a bare
`&tau-fedimint-bot` recipient here: its configured receiver policy can auto-start
an agent.

Delivery acknowledgement on stderr confirms durable acceptance, not task
completion. With `--wait-response`, stdout contains only the recipient's one
final response through its one-shot reply address. Without that flag, success
means durable acceptance only, and the CLI tells the recipient not to reply.

`--wait-response` waits indefinitely. An external timeout or disconnect can end
the wait without cancelling delivered work. A disconnect before
acknowledgement leaves delivery uncertain. Inspect the existing conversation
before considering another submission; do not retry an ambiguous send without
checking delivery.

The prior verification covered help and source for deployed Tau revision
`42495e547dc3299f86913f198ea5fd330b5a288b` (`docs/cli-message.md`,
`crates/tau-cli/src/message.rs`, and
`crates/tau-harness/src/harness/cli_messaging.rs`), not a live CLI round trip.
Recheck the installed help and source when the revision changes.

For an interactive fallback, use a PTY-capable connection and run
`tau_as_bot attach tau-fedimint-bot` on the runner. In the attached UI, select
the root you just discovered:

```text
:agent switch COORDINATOR_ID
```

Submit one bounded request, observe that same transcript, and leave with
`:detach`. Do not use `:quit-session`, cancellation, compaction, role/model
changes, or `:agent new` as health checks. A timeout is inconclusive: inspect
whether the input was accepted before considering another submission. Do not
automatically retry an ambiguous request.

## Do not mistake other transports for request/reply

* `tau dev send SESSION TEXT` creates a new parentless `engineer`; it does not
  message the existing coordinator and does not wait for model acceptance or a
  reply.
* Sending `:agent switch ...` through the headless send path is a no-op; separate
  `dev send` calls do not form a persistent selected-agent conversation.
* `--prompt-stdin` also creates a new agent rather than targeting the existing
  root.
* The agent's peer `message` tool is not the shell's `tau message` CLI. Neither
  is a host-qualified route to the remote runner. The CLI uses exact-session
  same-user UI admission but records `AgentMessageReceived` with `cli_origin`,
  not a `HumanUi` prompt or peer-tool authority.
* The GitHub notifier is an external integration path, not an administration
  channel. Do not manufacture an issue, comment, review, or identity to probe it.

## Use the service sandbox when needed

For an authorized operator command that must use the bot's complete isolate
profile, enter the bot's network namespace as root, then drop to `tau-fedimint`
and use the installed wrapper:

```sh
ip netns exec tau-fedimint runuser -u tau-fedimint -- \
  /etc/profiles/per-user/tau-fedimint/bin/tau-fedimint-sandbox TAU_ARGUMENT...
```

The wrapper uses the service's `fedimint-bot` profile, project-root working
directory, fixed HOME/XDG environment, config and state mounts, runtime
directory, SSH agent, and managed secret sources. It passes Tau arguments
literally. It does not call the service launcher, clear the fixed session, or
automatically attach to the running daemon. It refuses to run as another user,
outside the bot network namespace, or without the installed managed isolate config.
Ordinary SSH logins still use the host network. Host-side
`tau message` and `tau attach` use filesystem sockets and need no namespace entry.

Tau's `dev print-prompt` command configures ordinary extensions, which retain
their normal persistent state and startup side effects. Do not start a second
live GitHub notifier to inspect a prompt. Disable that extension
explicitly:

```sh
ip netns exec tau-fedimint runuser -u tau-fedimint -- \
  /etc/profiles/per-user/tau-fedimint/bin/tau-fedimint-sandbox \
  --disable-extension github-notifications \
  --role coordinator \
  dev print-prompt
```

Omitting the disable flag preserves ordinary Tau semantics and may start the
notifier. Other commands can also create a new harness or mutate state;
the wrapper supplies the service sandbox, not read-only administration
semantics.
