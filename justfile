default:
  @just --list

# Apply (deply) configuration to a host
apply HOST="runner-01" SSH_HOST="root@fedimint-runner-01":
  nixos-rebuild switch --flake .#{{HOST}} --target-host "{{SSH_HOST}}"

# Bootstrap host using nixos-anywhere
bootstrap HOST="runner-01" SSH_HOST="root@fedimint-runner-01":
  >&2 echo "Edit rule manually to prevent mistakes"
  exit 1
  nix run github:nix-community/nixos-anywhere -- --flake .#{{HOST}} {{SSH_HOST}}


# Edit agenix secret using given identity (private key)
agenix-edit PATH="secrets/github-runner.age" IDENTITY="$HOME/.ssh/id_ed25519.agenix":
  # Since agenix does not support yubikeys/ssh-agent , you might want to use
  # a standalone ssh key generated with `ssh-keygen -t ed25519`
  agenix -e "{{PATH}}" -i "{{IDENTITY}}"

# Build host configuration
build HOST="runner-01":
  nix build -L ".#nixosConfigurations.{{HOST}}.config.system.build.toplevel"

# Check flake for problems
check:
  nix flake check
  just --evaluate
