---
name: self-hosted-github-runners
description: Update this repository's self-hosted GitHub runner inputs and apply the runner configuration.
user-invocable: true
advertise: true
---

# Self-hosted github runners

Among other things, this repository contains NixOS configurations
for Fedimint's self-hosted github runners.


## Updating self-hosted GitHub runners

Runners need to be periodically updated, which means updating `nixpkgs`/NixOS
to a newer version, deploying new version to corresonding hosts and then
committing updates to the github repository.

Use this workflow when asked to update the self-hosted GitHub runners for this repository.

## Steps

1. Fetch master branch updates from git and rebase on top, so runner updates start from the latest repository state.

2. Update Nix flake inputs:

```bash
nix flake update
```

3. Apply the updated runner configuration.

Do not run `just apply-all-runners`: it can take too long as a single command and is harder to recover from.
Instead, inspect the repository `justfile`, find the uncommented `just apply-runner ...` lines in the
`apply-all-runners` recipe, and apply each runner individually with a long timeout.

At the time of writing, the recipe expands to:

```bash
just apply-runner "01"
just apply-runner "02"
just apply-runner "04"
just apply-runner "arm-01"
```

Use the current `justfile` as the source of truth if it differs from this list. Each `just apply-runner ...`
command can take a long time, so run it with a very long shell/tool timeout, e.g. 30 minutes or longer per runner.
If a runner fails, report exactly which runner failed and continue only if the failure is clearly unrelated and safe.

4. Commit
5. Publish a PR with new changes.
