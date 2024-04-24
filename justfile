default:
  @just --list

apply HOST="runner-01" SSH_HOST="root@fedimint-runner-01":
  nixos-rebuild switch --flake .#{{HOST}} --target-host "{{SSH_HOST}}"

bootstrap HOST="runner-01" SSH_HOST="root@fedimint-runner-01":
  nix run github:nix-community/nixos-anywhere -- --flake .#{{HOST}} {{SSH_HOST}}


# Since agenix does not support yubikeys/ssh-agent , you might want to use
# a standalone ssh key generated with `ssh-keygen -t ed25519`
agenix-edit PATH="secrets/github-runner.age" IDENTITY="$HOME/.ssh/id_ed25519.agenix":
  agenix -e "{{PATH}}" -i "{{IDENTITY}}"
