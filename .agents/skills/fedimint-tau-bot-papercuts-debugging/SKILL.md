---
name: fedimint-tau-bot-papercuts-debugging
description: >
  Diagnose the deployed Fedimint Tau bot safely, inspect its exact runtime and
  session state, and use only verified operator communication paths.
user-invocable: true
advertise: true
---

# Debug the Fedimint Tau bot

Use this skill when diagnosing the deployed bot or checking it after deployment.
Start read-only. Do not restart or clear the service, start a duplicate Tau
harness or notifier, dump secrets or full provider captures, or create synthetic
GitHub activity unless the operator separately authorizes that mutation.

A restart is especially destructive as a diagnostic: the deployed launcher
clears the fixed session before `serve --create`. It creates a new session
incarnation rather than refreshing the one under investigation.

## Discover the live runtime

Use an existing authorized operator connection to
`root@runner-01.dev.fedimint.org`. Discover the appropriate SSH invocation and
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
systemctl --user --machine=tau-fedimint@.host show \
  tau-fedimint-bot.service \
  -p ActiveState -p SubState -p MainPID -p ExecStart \
  -p FragmentPath -p ActiveEnterTimestamp
tau_as_bot session list --json
tau_as_bot agent list tau-fedimint-bot
```

This is a user service, not a system-level `tau-fedimint-bot.service`. Re-run
these commands after every deployment. Discover the current numeric UID, binary,
session, and root coordinator agent ID; never hard-code an old PID, socket hash,
UID, or agent ID. A stable session name does not identify one daemon incarnation.

For an operator command that must use the bot's complete isolate profile, log in
as `tau-fedimint` and use the installed wrapper:

```sh
tau-fedimint-sandbox TAU_ARGUMENT...
```

The wrapper selects the same `fedimint-bot` profile, project-root working
directory, fixed HOME/XDG environment, config and state mounts, runtime
directory, SSH agent, and managed secret sources as the service. It passes every
Tau argument literally. It does not call the service launcher, clear the fixed
session, or attach to the running daemon automatically, and it refuses to run as
another user or without the installed managed isolate config.

Tau's `dev print-prompt` command configures ordinary extensions, which retain
their normal persistent state and startup side effects. Do not start a second
live GitHub notifier merely to inspect a prompt. Disable that extension
explicitly:

```sh
tau-fedimint-sandbox \
  --disable-extension github-notifications \
  --role coordinator \
  dev print-prompt
```

Omitting the disable flag preserves ordinary Tau semantics and may start the
notifier. Other commands can likewise create a new harness or mutate state;
the wrapper supplies the service sandbox, not read-only administration
semantics.

## Triage from least to most sensitive

Use this order and stop as soon as the evidence answers the question:

1. Confirm the NixOS generation, exact Tau revision, service state/start time,
   and installed `ExecStart`.
2. Confirm exactly one expected live session and inspect its current agent tree.
3. Inspect content-free durable performance events for the freshly discovered
   coordinator:

   ```sh
   tau_as_bot agent trace COORDINATOR_ID --format agent-performance-jsonl
   ```

4. Query narrowly filtered service logs for the relevant time window.
5. Inspect semantic agent history only when necessary, using `tau agent trace`
   rather than decoding or editing state files directly.
6. Keep any necessary raw capture in an owner-private directory on the runner;
   sanitize conclusions before sharing them.

`agent-performance-jsonl` provides accounting without prompt/tool prose. Other
trace formats can contain sensitive conversation and tool content. Do not read
raw environment blocks, `/proc/*/environ`, agenix files, private keys, tokens,
or indiscriminate journals/provider captures. Extension stderr can also contain
unredacted content.

Interpret signals carefully:

* A running service proves liveness, not readiness.
* A coordinator waiting for activating input can be healthy and idle, not stuck.
* Session event logs are useful best-effort observations; durable agent journals
  hold the semantic conversation record.
* An empty session list from inside a supervised tool sandbox may reflect hidden
  runtime sockets. Inspect from the authenticated host before changing isolation.
* A model self-report is not independent proof of its binary, deployment, or
  surrounding service health.

## Communicate with the existing coordinator

Prefer `tau message --wait-response` for an authorized operator request. Sending
input mutates the live conversation; it is not a read-only health check and
requires explicit authorization.

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
completion. With `--wait-response`, stdout contains only the
recipient's one final response, sent through its one-shot reply address.
Without that flag, success means durable acceptance only and the recipient is
told not to reply.

`--wait-response` waits indefinitely. An external timeout or disconnect can end
the wait without cancelling delivered work. A disconnect before
acknowledgement leaves delivery uncertain. Inspect the existing conversation
before considering another submission; never blindly retry an ambiguous send.

Verification covered the help and source for deployed Tau revision
`42495e547dc3299f86913f198ea5fd330b5a288b` (`docs/cli-message.md`,
`crates/tau-cli/src/message.rs`, and
`crates/tau-harness/src/harness/cli_messaging.rs`), not a live CLI round trip.
Recheck installed help/source when the revision changes.

For an interactive fallback, use a PTY-capable connection and run
`tau_as_bot attach tau-fedimint-bot` on the runner. In the attached UI, select
the freshly discovered root:

```text
:agent switch COORDINATOR_ID
```

Submit one bounded request, observe that same transcript, and leave with
`:detach`. Do not use `:quit-session`, cancellation, compaction, role/model
changes, or `:agent new` as health checks. A timeout is inconclusive: inspect
whether the input was accepted before considering another submission, and never
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

## Post-deployment check

After deployment, verify read-only:

* the intended NixOS generation, installed Tau revision, and service start time;
* one expected daemon/notifier and the exact session/root coordinator;
* expected extension startup without a retry or error storm;
* the intended native coordinator bootstrap and current work state.

Request separate approval for one bounded CLI or attached-UI round-trip probe.
Record the exact daemon incarnation and target before sending, use a unique
nonce, and observe for a bounded interval. For a CLI probe, allow only the final
`message` reply to its one-shot address; forbid other tools and external actions.
For an attached-UI probe, ask for no tools or external actions.
Never restart the service or send a second prompt merely because the first
response is slow.

Escalate with the exact version, generation, target IDs, time window, minimal
sanitized evidence, uncertainty, and smallest proposed next probe. Route Tau
protocol defects to the Tau owner, integration behavior to the bridge owner,
and service/deployment faults to the infrastructure owner.
