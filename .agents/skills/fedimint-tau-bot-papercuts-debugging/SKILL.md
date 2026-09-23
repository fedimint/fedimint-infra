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

Run local inspection from a neutral directory such as `/tmp`. Entering this
infrastructure checkout can trigger direnv/Nix evaluation. Use the authenticated
operator path:

```sh
export SSH_AUTH_SOCK=/run/fedimint-ssh-agent/agent.sock
ssh -o BatchMode=yes -o ConnectTimeout=15 root@runner-01.dev.fedimint.org
```

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

The source-verified supported route is the interactive attached UI. This is a
real mutating user input, not a read-only health check, and therefore requires
explicit authorization. It has not yet been round-trip tested against this bot.

First discover the current root coordinator ID as above. Then attach with a PTY:

```sh
export SSH_AUTH_SOCK=/run/fedimint-ssh-agent/agent.sock
ssh -t root@runner-01.dev.fedimint.org \
  'runuser -u tau-fedimint -- env \
    HOME=/home/tau-fedimint \
    XDG_CONFIG_HOME=/home/tau-fedimint/.config \
    XDG_STATE_HOME=/home/tau-fedimint/.local/state \
    XDG_RUNTIME_DIR=/run/user/$(id -u tau-fedimint) \
    /run/current-system/sw/bin/tau attach tau-fedimint-bot'
```

Inside the UI, explicitly select the freshly discovered root:

```text
:agent switch COORDINATOR_ID
```

Submit one bounded request, observe that same transcript, and leave with
`:detach`. Do not use `:quit-session`, cancellation, compaction, role/model
changes, or `:agent new` as health checks. A timeout is inconclusive: inspect
whether the input was accepted before considering another submission, and never
automatically retry an ambiguous request.

The manual path is verified from Tau source to submit `HumanUi` input to the
selected existing agent. No operator request/reply round trip was performed as
part of establishing this skill, so describe it as source-verified rather than
live-tested until an authorized probe proves it.

## Do not mistake other transports for request/reply

There is currently no verified headless command that sends literal input to an
exact existing agent and returns its correlated reply.

These communication semantics were source-verified on September 23, 2026
against deployed Tau revision
`30c8b43410a84294f31f74451f9f7f09a94df473`. Recheck them against the newly
installed source whenever the deployed revision changes.

* `tau dev send SESSION TEXT` creates a new parentless `engineer`; it does not
  message the existing coordinator and does not wait for model acceptance or a
  reply.
* Sending `:agent switch ...` through the headless send path is a no-op; separate
  `dev send` calls do not form a persistent selected-agent conversation.
* `--prompt-stdin` also creates a new agent rather than targeting the existing
  root.
* Tau peer `message` discovers local runtime sockets and carries peer authority,
  not direct `HumanUi` authority. It is not a host-qualified route to the remote
  runner, and a bare receiver need not identify the exact existing coordinator.
* The GitHub notifier is an external integration path, not an administration
  channel. Do not manufacture an issue, comment, review, or identity to probe it.

A command such as `tau session request` is only a proposed upstream feature. Do
not present it as available. A safe implementation would need exact session and
agent targeting, literal stdin, fail-closed behavior without autostart, explicit
acceptance and reply correlation, bounded observation, and no retry after an
ambiguous post-send timeout. That upstream implementation is outside this
skill's scope.

## Post-deployment check

After deployment, verify read-only:

* the intended NixOS generation, installed Tau revision, and service start time;
* one expected daemon/notifier and the exact session/root coordinator;
* expected extension startup without a retry or error storm;
* the intended native coordinator bootstrap and current work state.

Request a separate approval for one bounded attached-UI round-trip probe. Record
the exact daemon incarnation and target before sending, use a unique nonce, ask
for no tools or external actions, and observe for a bounded interval. Never
restart the service or send a second prompt merely because the first response is
slow.

Escalate with the exact version, generation, target IDs, time window, minimal
sanitized evidence, uncertainty, and smallest proposed next probe. Route Tau
protocol defects to the Tau owner, integration behavior to the bridge owner,
and service/deployment faults to the infrastructure owner.
