default:
  @just --list

# Apply (deply) configuration to a host, evaluating and building locally
apply HOST SSH_HOST:
  nixos-rebuild switch --cores 8 -L --flake .#{{HOST}} --target-host "{{SSH_HOST}}"

# Only the git-tracked working tree is sent over ssh; the target then fetches
# the flake inputs, evaluates, builds and switches. Worth it for hosts that are
# beefier and better-connected than the workstation (the runners), and it also
# avoids needing an aarch64 builder locally. The target needs a trusted root
# login and enough disk/RAM to build a full system closure.

# Apply (deply) configuration to a host, evaluating and building on the target
apply-on-target HOST SSH_HOST:
  #!/usr/bin/env bash
  set -euo pipefail

  host={{ quote(HOST) }}
  ssh_host={{ quote(SSH_HOST) }}
  repo_root=$(git -C {{ quote(justfile_directory()) }} rev-parse --show-toplevel)
  remote_dir=

  cleanup() {
    if [ -n "$remote_dir" ]; then
      ssh -- "$ssh_host" "rm -rf -- '$remote_dir'" || true
    fi
  }
  trap cleanup EXIT

  candidate=$(ssh -- "$ssh_host" 'mktemp -d /tmp/fedimint-infra.XXXXXXXXXX')
  if [[ ! "$candidate" =~ ^/tmp/fedimint-infra\.[[:alnum:]]+$ ]]; then
    echo "Remote mktemp returned an unexpected path: $candidate" >&2
    exit 1
  fi
  remote_dir=$candidate

  # Match what a git-backed flake would see: tracked paths with local
  # modifications included, untracked and ignored files (plaintext secrets,
  # ./result, .direnv) left behind. The tracked .age secrets are sent, the
  # target decrypts them with its own host key as usual.
  git -C "$repo_root" ls-files -z \
    | while IFS= read -r -d '' path; do
        if [ -e "$repo_root/$path" ] || [ -L "$repo_root/$path" ]; then
          printf '%s\0' "$path"
        fi
      done \
    | tar -C "$repo_root" --no-recursion --null --files-from=- -czf - \
    | ssh -- "$ssh_host" "tar -xzf - -C '$remote_dir'"

  ssh -- "$ssh_host" \
    "cd $(printf '%q' "$remote_dir") && nixos-rebuild switch -L --flake .#$(printf '%q' "$host")"

apply-runner RUNNER:
  just apply-on-target "runner-{{RUNNER}}" "root@runner-{{RUNNER}}.dev.fedimint.org"

apply-fedimintd N:
  just apply "fedimintd-{{N}}" "root@fedimintd-{{N}}.dev.fedimint.org"

apply-all-runners:
  just apply-runner "01"
  just apply-runner "02"
  # just apply-runner "03"
  just apply-runner "04"
  just apply-runner "arm-01"

apply-all-fedimintd:
  just apply-fedimintd "01"
  just apply-fedimintd "02"
  just apply-fedimintd "03"
  just apply-fedimintd "04"

apply-all-iroh:
  just apply irohdns-eu-01 "root@irohdns-eu-01.dev.fedimint.org"
  just apply irohdns-us-01 "root@irohdns-us-01.dev.fedimint.org"
  just apply irohrelay-eu-01 "root@irohrelay-eu-01.dev.fedimint.org"
  just apply irohrelay-us-01 "root@irohrelay-us-01.dev.fedimint.org"

apply-all:
  just apply-all-runners
  just apply-all-fedimintd
  just apply-all-iroh

# Bootstrap host using nixos-anywhere
bootstrap HOST SSH_HOST:
  nix run github:nix-community/nixos-anywhere -- --flake .#{{HOST}} {{SSH_HOST}}


# Edit agenix secret using given identity (private key)
agenix-edit PATH="secrets/github-runner.age" IDENTITY="$HOME/.ssh/id_ed25519.agenix":
  # Since agenix does not support yubikeys/ssh-agent , you might want to use
  # a standalone ssh key generated with `ssh-keygen -t ed25519`
  agenix -e "{{PATH}}" -i "{{IDENTITY}}"

agenix-rekey IDENTITY="$HOME/.ssh/id_ed25519.agenix":
  agenix -r -i "{{IDENTITY}}"

# Build host configuration
build HOST:
  nix build -L ".#nixosConfigurations.{{HOST}}.config.system.build.toplevel"

# Check flake for problems
check:
  nix flake check
  just --evaluate
