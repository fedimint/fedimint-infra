{
  system,
  nixpkgs,
  agenix,
  module,
  tauPackage,
  githubNotificationsPackage,
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
    inherit tauPackage;
    isolatePackage = dummyPackage "isolate";
    ghBrokerPackage = dummyPackage "gh-broker";
    clankPackage = dummyPackage "clank";
    githubTokenAgeFile = actionToken;
    sshPrivateKeyAgeFile = sshKey;
    sshAuthorizedKeys = [ "ssh-ed25519 test-only" ];
  };
  mkSystem =
    {
      githubNotifications,
      providerProfile ? null,
    }:
    nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        agenix.nixosModules.default
        module
        {
          system.stateVersion = "26.05";
          services.tau-fedimint-bot =
            common
            // {
              inherit githubNotifications;
            }
            // lib.optionalAttrs (providerProfile != null) {
              inherit providerProfile;
            };
        }
      ];
    };
  defaultDisabled = mkSystem {
    githubNotifications = { };
  };
  disabled = mkSystem {
    githubNotifications.package = githubNotificationsPackage;
  };
  alternateProvider = mkSystem {
    githubNotifications = { };
    providerProfile = "future-provider";
  };
  enabled = mkSystem {
    githubNotifications = {
      enable = true;
      package = githubNotificationsPackage;
      tokenAgeFile = notificationToken;
      identityKeyAgeFile = identityKey;
    };
  };
  reusedToken = mkSystem {
    githubNotifications = {
      enable = true;
      package = githubNotificationsPackage;
      tokenAgeFile = actionToken;
      identityKeyAgeFile = identityKey;
    };
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
  alternateProviderStart =
    alternateProvider.config.systemd.user.services.tau-fedimint-bot.serviceConfig.ExecStart;
  enabledStart = enabled.config.systemd.user.services.tau-fedimint-bot.serviceConfig.ExecStart;
  privateDirectoryRules = map (path: "d ${path} 0700 tau-fedimint tau-fedimint -") [
    "/home/tau-fedimint/fedimint"
    "/home/tau-fedimint/.config"
    "/home/tau-fedimint/.config/isolate"
    "/home/tau-fedimint/.config/tau"
    "/home/tau-fedimint/.local"
    "/home/tau-fedimint/.local/state"
    "/home/tau-fedimint/.local/state/tau"
    "/home/tau-fedimint/.local/state/clank"
    "/home/tau-fedimint/.cache"
    "/home/tau-fedimint/.cache/tau"
  ];
  configCheck =
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
        alternate_provider_harness=$(
          sed -n 's#.*install -m 0600 \([^ ]*harness.yaml\).*#\1#p' ${alternateProviderStart}
        )
        enabled_harness=$(
          sed -n 's#.*install -m 0600 \([^ ]*harness.yaml\).*#\1#p' ${enabledStart}
        )
        disabled_isolate=$(
          sed -n 's#.*install -m 0600 \([^ ]*isolate.yaml\).*#\1#p' ${disabledStart}
        )
        enabled_isolate=$(
          sed -n 's#.*install -m 0600 \([^ ]*isolate.yaml\).*#\1#p' ${enabledStart}
        )
        test -n "$disabled_harness"
        test -n "$alternate_provider_harness"
        test -n "$enabled_harness"
        test -n "$disabled_isolate"
        test -n "$enabled_isolate"

        jq -e '
          (.extensions["github-notifications"] == null)
          and (.aliases.providers.codex == "chatgpt-dpc")
          and (.agents.model == "codex/gpt-5.6-luna")
          and (.agents.role_groups.coordinator.roles.coordinator.enable_tools == [])
        ' "$disabled_harness" >/dev/null
        jq -e '
          (.aliases.providers.codex == "future-provider")
          and (.agents.model == "codex/gpt-5.6-luna")
        ' "$alternate_provider_harness" >/dev/null
        jq -e '
          (.profiles["fedimint-bot"].setenv.TAU_SECRET_GITHUB_TOKEN == null)
          and (.profiles["fedimint-bot"].setenv.TAU_SECRET_GITHUB_IDENTITY_KEY == null)
        ' "$disabled_isolate" >/dev/null
        ! grep -q '${githubNotificationsPackage}' "$disabled_harness"
        bot_unit=${
          disabled.config.systemd.user.units."tau-fedimint-bot.service".unit
        }/tau-fedimint-bot.service
        grep -q '^UnsetEnvironment=TAU_MODEL_ALIASES$' "$bot_unit"
        grep -q '^UnsetEnvironment=TAU_PROFILE$' "$bot_unit"
        grep -q '^UnsetEnvironment=TAU_PROVIDER_ALIASES$' "$bot_unit"

        test_home="$TMPDIR/tau-home"
        test_workspace="$TMPDIR/workspace"
        mkdir -p "$test_home/.config/tau" "$test_workspace"
        jq --arg workspace "$test_workspace" '
          .extensions["core-shell"].config.working_directory = $workspace
          | .extensions["core-shell"].config.shell.allowlist[0].workdir = $workspace
          | .extensions["core-shell"].config.shell.allowlist[1].workdir = ($workspace + "/**")
          | .inter_session.allow_project_roots = [$workspace, ($workspace + "/**")]
        ' "$disabled_harness" >"$test_home/.config/tau/harness.yaml"
        env -u TAU_PROFILE -u TAU_PROVIDER_ALIASES -u TAU_MODEL_ALIASES \
          HOME="$test_home" \
          XDG_CONFIG_HOME="$test_home/.config" \
          XDG_STATE_HOME="$test_home/.local/state" \
          XDG_CACHE_HOME="$test_home/.cache" \
          ${tauPackage}/bin/tau --role coordinator dev print-system-prompt >/dev/null

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
            "repositories": ["fedimint/fedimint", "fedimint/fedimint-sdk"],
            "token_secret": "github_token"
          })
          and (.agents.role_groups.coordinator.roles.coordinator.enable_tools == ["github_register"])
        ' "$enabled_harness" >/dev/null
        grep -q '${githubNotificationsPackage}/bin/tau-ext-github' "$enabled_harness"
        jq -e \
          --arg token '/run/agenix/tau-fedimint-github-notifications-token' \
          --arg identity '/run/agenix/tau-fedimint-github-notifications-identity-key' '
          (.profiles["fedimint-bot"].setenv.TAU_SECRET_GITHUB_TOKEN == {"file": $token})
          and (
            .profiles["fedimint-bot"].setenv.TAU_SECRET_GITHUB_IDENTITY_KEY
            == {"file": $identity}
          )
        ' "$enabled_isolate" >/dev/null
        jq -e '
          [.profiles["fedimint-bot"].bind[]
            | select(.path == "/run/systemd/resolve/stub-resolv.conf")]
          == [{
            path: "/run/systemd/resolve/stub-resolv.conf",
            required: true,
            kind: "file"
          }]
        ' "$disabled_isolate" >/dev/null

        touch "$out"
      '';
  tmpfilesCheck = pkgs.testers.runNixOSTest {
    name = "tau-fedimint-bot-tmpfiles";
    nodes.machine = {
      system.stateVersion = "26.05";
      users.groups.tau-fedimint.gid = 991;
      users.users.tau-fedimint = {
        isNormalUser = true;
        uid = 1001;
        group = "tau-fedimint";
        home = "/home/tau-fedimint";
        createHome = true;
      };
      systemd.tmpfiles.rules = disabled.config.systemd.tmpfiles.rules;
    };
    testScript = ''
      start_all()

      machine.succeed(
          "rm -rf "
          "/home/tau-fedimint/.config/isolate "
          "/home/tau-fedimint/.config/tau "
          "/home/tau-fedimint/.local/state/tau "
          "/home/tau-fedimint/.local/state/clank "
          "/home/tau-fedimint/.cache/tau"
      )
      machine.succeed(
          "chown root:root "
          "/home/tau-fedimint/.config "
          "/home/tau-fedimint/.local "
          "/home/tau-fedimint/.local/state "
          "/home/tau-fedimint/.cache"
      )
      machine.succeed(
          "chmod 0755 "
          "/home/tau-fedimint/.config "
          "/home/tau-fedimint/.local "
          "/home/tau-fedimint/.local/state "
          "/home/tau-fedimint/.cache"
      )

      machine.succeed("systemd-tmpfiles --create")

      for path in ${
        builtins.toJSON [
          "/home/tau-fedimint/fedimint"
          "/home/tau-fedimint/.config"
          "/home/tau-fedimint/.config/isolate"
          "/home/tau-fedimint/.config/tau"
          "/home/tau-fedimint/.local"
          "/home/tau-fedimint/.local/state"
          "/home/tau-fedimint/.local/state/tau"
          "/home/tau-fedimint/.local/state/clank"
          "/home/tau-fedimint/.cache"
          "/home/tau-fedimint/.cache/tau"
        ]
      }:
          machine.succeed(
              f"test \"$(stat -c '%u:%g:%a' '{path}')\" = 1001:991:700"
          )
    '';
  };
in
assert failedBotAssertions defaultDisabled == [ ];
assert failedBotAssertions disabled == [ ];
assert failedBotAssertions enabled == [ ];
assert builtins.length (failedBotAssertions reusedToken) == 1;
assert lib.all (rule: lib.elem rule disabled.config.systemd.tmpfiles.rules) privateDirectoryRules;
assert !(defaultDisabled.config.age.secrets ? "tau-fedimint-github-notifications-token");
assert !(defaultDisabled.config.age.secrets ? "tau-fedimint-github-notifications-identity-key");
assert !(disabled.config.age.secrets ? "tau-fedimint-github-notifications-token");
assert !(disabled.config.age.secrets ? "tau-fedimint-github-notifications-identity-key");
assert !(lib.elem githubNotificationsPackage disabled.config.environment.systemPackages);
assert lib.elem pkgs.bubblewrap disabled.config.systemd.user.services.tau-fedimint-bot.path;
pkgs.linkFarm "tau-fedimint-bot-checks" [
  {
    name = "config";
    path = configCheck;
  }
  {
    name = "tmpfiles";
    path = tmpfilesCheck;
  }
]
