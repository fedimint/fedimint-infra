{
  system,
  nixpkgs,
  automationPublicKey,
  adminKeys,
  runnerRootAuthorizedKeys,
  nonRunnerRootAuthorizedKeys,
  botAuthorizedKeys,
}:

let
  pkgs = nixpkgs.legacyPackages.${system};
in
assert builtins.all (keys: keys == adminKeys ++ [ automationPublicKey ]) runnerRootAuthorizedKeys;
assert builtins.all (keys: keys == adminKeys) nonRunnerRootAuthorizedKeys;
assert botAuthorizedKeys == adminKeys;
assert !(builtins.elem automationPublicKey adminKeys);
pkgs.runCommand "runner-root-ssh-authorization-check" { } ''
  touch "$out"
''
