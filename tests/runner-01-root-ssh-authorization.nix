{
  system,
  nixpkgs,
  automationPublicKey,
  adminKeys,
  runner01RootAuthorizedKeys,
  runner02RootAuthorizedKeys,
  botAuthorizedKeys,
}:

let
  pkgs = nixpkgs.legacyPackages.${system};
in
assert runner01RootAuthorizedKeys == adminKeys ++ [ automationPublicKey ];
assert runner02RootAuthorizedKeys == adminKeys;
assert botAuthorizedKeys == adminKeys;
assert !(builtins.elem automationPublicKey adminKeys);
pkgs.runCommand "runner-01-root-ssh-authorization-check" { } ''
  touch "$out"
''
