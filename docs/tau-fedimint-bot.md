# Tau Fedimint bot

The bot runs as `tau-fedimint` on runner-01, in the user systemd service
`tau-fedimint-bot.service`. One coordinator handles GitHub work, admitted Discord
requests, and scheduled maintenance.

## Where to look

| Concern | Source |
| --- | --- |
| Service, sandbox, role prompts, schedules, and options | [`modules/tau-fedimint-bot.nix`](../modules/tau-fedimint-bot.nix) |
| Enabled runner configuration and package pins | [`flake.nix`](../flake.nix), [`flake.lock`](../flake.lock) |
| Task policy and workflows | [`.agents/skills`](../.agents/skills) |
| Integration checks | [`tests/tau-fedimint-bot.nix`](../tests/tau-fedimint-bot.nix) |
| Secret recipients and encrypted sources | [`secrets.nix`](../secrets.nix), `secrets/` |

Use the [operator skill](../.agents/skills/fedimint-tau-bot/SKILL.md) to contact
the existing coordinator and the
[debugging skill](../.agents/skills/fedimint-tau-bot-papercuts-debugging/SKILL.md)
for diagnostics. Follow task skills for authorization and publication rules;
notification admission alone does not authorize work.

## Deployment boundaries

The sandbox brokers GitHub actions and keeps the action token outside the bot.
Isolate guards against accidental agent actions, not hostile code: it shares the
host network and exposes runtime state and an SSH agent. Browser CDP uses
unauthenticated host loopback, an accepted tradeoff for this trusted single-user
deployment.

Restarting the service discards the live session and sends a recovery request to
a new coordinator. Repository and Clank state survive. Follow the operator skill's
fix-forward deployment policy; a live prompt starts work, so it is not a health
probe.

## Validation

For integration changes:

```console
nix build .#checks.x86_64-linux.tau-fedimint-bot-config
nix build .#nixosConfigurations.runner-01.config.system.build.toplevel
```

These offline checks do not verify live credentials or external delivery.
