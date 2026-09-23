{
  system,
  nixpkgs,
  nixosConfigurations,
  secretPolicies,
}:

let
  pkgs = nixpkgs.legacyPackages.${system};
  backupPath = "secrets/tau-fedimint-github-password.age";
  backupRecipients = secretPolicies.${backupPath}.publicKeys;
  adminRecipients = secretPolicies."secrets/perfitd-info.age".publicKeys;
  otherAdminOnlyRecipients = secretPolicies."secrets/fedimint-signet-demo.age".publicKeys;
  runtimeSecretFiles = builtins.concatMap (
    configuration:
    map (secret: toString secret.file) (builtins.attrValues configuration.config.age.secrets)
  ) (builtins.attrValues nixosConfigurations);
  backupSource = "${toString ../.}/${backupPath}";
in
assert backupRecipients == adminRecipients;
assert backupRecipients == otherAdminOnlyRecipients;
assert !(builtins.elem backupSource runtimeSecretFiles);
pkgs.runCommand "tau-fedimint-github-password-backup-check" { } ''
  touch "$out"
''
