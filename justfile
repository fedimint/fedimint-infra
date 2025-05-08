default:
  @just --list

# Apply (deply) configuration to a host
apply HOST SSH_HOST:
  nixos-rebuild switch -L --flake .#{{HOST}} --target-host "{{SSH_HOST}}"

apply-runner RUNNER:
  just apply "runner-{{RUNNER}}" "root@runner-{{RUNNER}}.dev.fedimint.org"

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
