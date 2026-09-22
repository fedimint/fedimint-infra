{
  system,
  nixpkgs,
  agenix,
  module,
}:

let
  lib = nixpkgs.lib;
  pkgs = nixpkgs.legacyPackages.${system};
  dummyPackage =
    name:
    pkgs.writeShellScriptBin name ''
      echo "test-only package" >&2
      exit 1
    '';
  actionToken = builtins.toFile "action-token.age" "test-only";
  notificationToken = builtins.toFile "notification-token.age" "test-only";
  identityKey = builtins.toFile "notification-identity-key.age" "test-only";
  sshKey = builtins.toFile "ssh-private-key.age" "test-only";
  common = {
    enable = true;
    tauPackage = dummyPackage "tau";
    isolatePackage = dummyPackage "isolate";
    ghBrokerPackage = dummyPackage "gh-broker";
    clankPackage = dummyPackage "clank";
    githubTokenAgeFile = actionToken;
    sshPrivateKeyAgeFile = sshKey;
    sshAuthorizedKeys = [ "ssh-ed25519 test-only" ];
  };
  mkSystem =
    githubNotifications:
    nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        agenix.nixosModules.default
        module
        {
          system.stateVersion = "26.05";
          services.tau-fedimint-bot = common // {
            inherit githubNotifications;
          };
        }
      ];
    };
  disabled = mkSystem { };
  enabled = mkSystem {
    enable = true;
    package = dummyPackage "tau-ext-github";
    tokenAgeFile = notificationToken;
    identityKeyAgeFile = identityKey;
  };
  reusedToken = mkSystem {
    enable = true;
    package = dummyPackage "tau-ext-github";
    tokenAgeFile = actionToken;
    identityKeyAgeFile = identityKey;
  };
  failedBotAssertions =
    systemConfig:
    builtins.filter (
      assertion:
      !assertion.assertion
      && (
        lib.hasPrefix "tau-fedimint-bot " assertion.message
        || lib.hasPrefix "GitHub notifications " assertion.message
        || lib.hasPrefix "GitHub notification " assertion.message
      )
    ) systemConfig.config.assertions;
  disabledStart = disabled.config.systemd.user.services.tau-fedimint-bot.serviceConfig.ExecStart;
  enabledStart = enabled.config.systemd.user.services.tau-fedimint-bot.serviceConfig.ExecStart;
in
assert failedBotAssertions disabled == [ ];
assert failedBotAssertions enabled == [ ];
assert builtins.length (failedBotAssertions reusedToken) == 1;
assert !(disabled.config.age.secrets ? "tau-fedimint-github-notifications-token");
assert !(disabled.config.age.secrets ? "tau-fedimint-github-notifications-identity-key");
pkgs.runCommand "tau-fedimint-bot-config-check"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.jq
    ];
  }
  ''
    set -euo pipefail

    disabled_harness=$(
      sed -n 's#.*install -m 0600 \([^ ]*harness.yaml\).*#\1#p' ${disabledStart}
    )
    enabled_harness=$(
      sed -n 's#.*install -m 0600 \([^ ]*harness.yaml\).*#\1#p' ${enabledStart}
    )
    test -n "$disabled_harness"
    test -n "$enabled_harness"

    jq -e '
      (.extensions["github-notifications"] == null)
      and (.agents.role_groups.coordinator.roles.coordinator.enable_tools == [])
    ' "$disabled_harness" >/dev/null
    ! grep -q 'TAU_SECRET_GITHUB_' ${disabledStart}

    jq -e '
      .extensions["github-notifications"] as $extension
      | ($extension.enable == true)
      and ($extension.command | length == 1)
      and ($extension.command[0] | endswith("/bin/tau-ext-github"))
      and ($extension.secrets | keys == ["github_identity_key", "github_token"])
      and ($extension.config == {
        "actors": {"mode": "repository_maintainers"},
        "identity_key_secret": "github_identity_key",
        "poll_seconds": 60,
        "repositories": ["fedimint/fedimint"],
        "token_secret": "github_token"
      })
      and (.agents.role_groups.coordinator.roles.coordinator.enable_tools == ["github_register"])
    ' "$enabled_harness" >/dev/null
    grep -q 'TAU_SECRET_GITHUB_TOKEN=' ${enabledStart}
    grep -q 'TAU_SECRET_GITHUB_IDENTITY_KEY=' ${enabledStart}

    touch "$out"
  ''
