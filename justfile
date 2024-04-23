apply HOST="runner-01":
  nixos-rebuild switch --flake .#{{HOST}} --target-host "root@{{HOST}}"

bootstrap HOST="runner-01" SSH_HOST="fedimint-runner-01":
  nix run github:nix-community/nixos-anywhere -- --flake .#{{HOST}} root@{{SSH_HOST}}
