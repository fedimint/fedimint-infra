---
name: fedimint-tau-bot-papercuts-debugging
description: >
  Diagnose the deployed Fedimint Tau bot safely, triage runtime evidence, and
  check service health after deployment.
user-invocable: true
advertise: true
---

# Debug the Fedimint Tau bot

Use this skill when diagnosing the deployed bot or checking it after deployment.
First load [fedimint-tau-bot](../fedimint-tau-bot/SKILL.md) and follow its
runtime discovery instructions. Use that skill's authorized runner connection,
`tau_as_bot` helper, and current session/root coordinator throughout these steps.
Follow its operator communication instructions and sandbox wrapper precautions;
do not substitute a new harness or notifier.

Start read-only. On restart, the deployed launcher clears the fixed session
before `serve --create`. It creates a
new session incarnation rather than refreshing the one under investigation.

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

4. Filter service logs to the relevant events and time window.
5. Inspect semantic agent history only when necessary, using `tau agent trace`
   rather than decoding or editing state files directly.
6. Keep any necessary raw capture in an owner-private directory on the runner;
   sanitize conclusions before sharing them.

`agent-performance-jsonl` provides accounting without prompt/tool prose. Other
trace formats can contain sensitive conversation and tool content. Do not read
raw environment blocks, `/proc/*/environ`, agenix files, private keys, tokens,
or indiscriminate journals/provider captures. Extension stderr can also contain
unredacted content.

Interpret the evidence:

* A running service proves liveness, not readiness.
* A coordinator waiting for activating input can be healthy and idle, not stuck.
* Session event logs are useful best-effort observations; durable agent journals
  hold the semantic conversation record.
* An empty session list from inside a supervised tool sandbox may reflect hidden
  runtime sockets. Inspect from the authenticated host before changing isolation.
* A model self-report is not independent proof of its binary, deployment, or
  surrounding service health.

## Post-deployment check

After deployment, use read-only checks to verify:

* the intended NixOS generation, installed Tau revision, and service start time;
* one expected daemon/notifier and the exact session/root coordinator;
* expected extension startup without a retry or error storm;
* the intended native coordinator bootstrap and current work state.

Request separate approval for one bounded CLI or attached-UI round-trip probe.
Follow the general skill's
[communication instructions](../fedimint-tau-bot/SKILL.md#communicate-with-the-existing-coordinator).
Record the exact daemon incarnation and target before sending, use a unique
nonce, and observe for a bounded interval. For a CLI probe, allow only the final
`message` reply to its one-shot address; forbid other tools and external actions.
For an attached-UI probe, ask for no tools or external actions.
Never restart the service or send a second prompt because the first
response is slow.

Escalate with the exact version, generation, target IDs, time window, minimal
sanitized evidence, uncertainty, and smallest proposed next probe. Route Tau
protocol defects to the Tau owner, integration behavior to the bridge owner,
and service/deployment faults to the infrastructure owner.
