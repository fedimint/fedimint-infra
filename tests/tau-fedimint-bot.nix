{
  system,
  nixpkgs,
  agenix,
  module,
  tauPackage,
  isolatePackage,
  ghBrokerPackage,
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
  dummyIsolatePackage = pkgs.writeShellScriptBin "isolate" ''
    echo "test-only isolate" >&2
    exit 42
  '';
  actionToken = builtins.toFile "action-token.age" "test-only";
  notificationToken = builtins.toFile "notification-token.age" "test-only";
  identityKey = builtins.toFile "notification-identity-key.age" "test-only";
  sshKey = builtins.toFile "ssh-private-key.age" "test-only";
  devShellSmoke = pkgs.mkShell {
    packages = [ pkgs.just ];
  };
  common = {
    enable = true;
    inherit tauPackage;
    isolatePackage = dummyIsolatePackage;
    inherit ghBrokerPackage;
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
  githubRequesterPackage = lib.findFirst (
    package: lib.getName package == "fedimint-github-requester"
  ) (throw "fedimint-github-requester package missing") disabled.config.environment.systemPackages;
  direnvDpcPackage = lib.findFirst (
    package: lib.getName package == "direnv-dpc"
  ) (throw "direnv-dpc package missing") disabled.config.environment.systemPackages;
  alternateProviderStart =
    alternateProvider.config.systemd.user.services.tau-fedimint-bot.serviceConfig.ExecStart;
  enabledStart = enabled.config.systemd.user.services.tau-fedimint-bot.serviceConfig.ExecStart;
  privateDirectoryRules = map (path: "d ${path} 0700 tau-fedimint tau-fedimint -") [
    "/home/tau-fedimint/fedimint"
    "/home/tau-fedimint/.config"
    "/home/tau-fedimint/.config/isolate"
    "/home/tau-fedimint/.config/tau"
    "/home/tau-fedimint/.local"
    "/home/tau-fedimint/.local/share"
    "/home/tau-fedimint/.local/share/direnv"
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
          pkgs.git
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
        git_config=$(
          sed -n 's#.*install -m 0600 \([^ ]*gitconfig\).*#\1#p' ${disabledStart}
        )
        test -n "$disabled_harness"
        test -n "$alternate_provider_harness"
        test -n "$enabled_harness"
        test -n "$disabled_isolate"
        test -n "$enabled_isolate"
        test -n "$git_config"

        for config in "$disabled_harness" "$alternate_provider_harness" "$enabled_harness" \
          "$disabled_isolate" "$enabled_isolate"; do
          test "$(wc -l <"$config")" -gt 1
          grep -q '^  "' "$config"
          jq --indent 2 . "$config" | cmp -s - "$config"
        done

        test "$(${pkgs.git}/bin/git config --file "$git_config" user.name)" = "fedimint-tau"
        test "$(${pkgs.git}/bin/git config --file "$git_config" user.email)" = \
          "332691140+fedimint-tau@users.noreply.github.com"

        jq -e '
          (.extensions["github-notifications"] == null)
          and (.aliases.providers.codex == "chatgpt-dpc")
          and (.agents.model == "codex/gpt-6-sol")
          and (.agents.effort == 0.5)
          and (.agents.compactions == {
            "compact-after-done": {
              threshold: 100000,
              when: {
                at: "outer_turn_finished",
                statuses: ["done"]
              }
            },
            "compact-after-done-any-status": {
              threshold: 250000,
              when: {
                at: "outer_turn_finished"
              }
            }
          })
          and (.agents.role_groups.coordinator.roles.coordinator.model == "codex/gpt-6-sol")
          and (.agents.role_groups.coordinator.roles.coordinator.effort == 0.5)
          and (.agents.role_groups.coordinator.roles.coordinator.compactions == {
            "compact-after-done": {
              threshold: 100000,
              when: {
                at: "outer_turn_finished",
                statuses: ["done", "waiting"]
              }
            },
            "compact-after-done-any-status": {
              threshold: 150000,
              when: {
                at: "outer_turn_finished"
              }
            }
          })
          and (.agents.role_groups.engineer.roles["engineer-junior"].model == "codex/gpt-6-sol")
          and (.agents.role_groups.engineer.roles["engineer-junior"].effort == 0.25)
          and (.agents.role_groups.engineer.roles.engineer.model == "codex/gpt-6-sol")
          and (.agents.role_groups.engineer.roles.engineer.effort == 0.5)
          and (.agents.role_groups.engineer.roles["engineer-senior"].model == "codex/gpt-6-sol")
          and (.agents.role_groups.engineer.roles["engineer-senior"].effort == 0.5)
          and (.agents.role_groups.support.roles.researcher.model == "codex/gpt-6-sol")
          and (.agents.role_groups.support.roles.researcher.effort == 0.25)
          and (.agents.role_groups.support.roles["researcher-senior"].model == "codex/gpt-6-sol")
          and (.agents.role_groups.support.roles["researcher-senior"].effort == 0.5)
          and (.agents.role_groups.support.roles.reviewer.model == "codex/gpt-6-sol")
          and (.agents.role_groups.support.roles.reviewer.effort == 0.5)
          and (.agents.role_groups.coordinator.roles.coordinator.enable_tools == [])
          and (.extensions["core-shell"].config.shell.prefix == [
            "direnv-dpc",
            "exec",
            "."
          ])
        ' "$disabled_harness" >/dev/null
        jq -e '
          (.aliases.providers.codex == "future-provider")
          and (.agents.model == "codex/gpt-6-sol")
        ' "$alternate_provider_harness" >/dev/null
        jq -r '
          [
            .agents.prompt_fragments[].text,
            .agents.role_groups.coordinator.prompt_fragments[].text,
            .agents.role_groups.engineer.prompt_fragments[].text,
            .agents.role_groups.support.prompt_fragments[].text,
            .agents.role_groups.support.roles.reviewer.prompt_fragments[].text
          ] | join("\n")
        ' "$disabled_harness" >"$TMPDIR/bot-prompts"
        grep -q 'Lead with the answer, outcome' "$TMPDIR/bot-prompts"
        grep -q 'one canonical open `ACTIVE QUEUE` ticket' "$TMPDIR/bot-prompts"
        grep -q 'independent passing review' "$TMPDIR/bot-prompts"
        grep -q 'relevant history' "$TMPDIR/bot-prompts"
        grep -q 'source and history read-only' "$TMPDIR/bot-prompts"
        grep -q 'Do not modify project source or history' "$TMPDIR/bot-prompts"
        grep -Fq '`direnv-dpc exec .`' "$TMPDIR/bot-prompts"
        grep -Fq 'then run `direnv-dpc allow` in that workdir' "$TMPDIR/bot-prompts"
        grep -Fq "equivalent of \`direnv allow\`" "$TMPDIR/bot-prompts"
        grep -Fq 'Do not blindly' "$TMPDIR/bot-prompts"
        grep -Fq 'Until approval, commands warn and run without the' "$TMPDIR/bot-prompts"
        grep -Fq 'cargo fetch --locked && just final-lint' "$TMPDIR/bot-prompts"
        grep -Fq \
          "nix develop . --command bash -lc 'cargo fetch --locked && just final-lint'" \
          "$TMPDIR/bot-prompts"
        ! grep -Fq 'Never run `direnv allow` yourself' "$TMPDIR/bot-prompts"
        ! grep -Eiq 'jujutsu|(^|[^[:alnum:]_])jj([^[:alnum:]_]|$)' "$TMPDIR/bot-prompts"
        jq -er '
          .agents.prompt_fragments[]
          | select(.name == "fedimint-bot.scope")
          | .text
        ' "$disabled_harness" >"$TMPDIR/scope-prompt"
        grep -q 'approved read-only GitHub inspection' "$TMPDIR/scope-prompt"
        grep -Fq '`gh issue view` or `gh pr view`' "$TMPDIR/scope-prompt"
        grep -q 'public issue or pull request' "$TMPDIR/scope-prompt"
        grep -q 'access non-public data with credentials' "$TMPDIR/scope-prompt"
        grep -q 'Public read-only issue or pull-request inspection does not' \
          "$TMPDIR/scope-prompt"
        jq -er '
          .agents.role_groups.coordinator.prompt_fragments[]
          | select(.name == "coordinator.instructions")
          | .text
        ' "$disabled_harness" >"$TMPDIR/coordinator-prompt"
        grep -q 'maintainer activity as a request' "$TMPDIR/coordinator-prompt"
        grep -q 'check USERNAME maintainer' "$TMPDIR/coordinator-prompt"
        grep -q 'Proactively review every newly opened pull request' "$TMPDIR/coordinator-prompt"
        grep -Fq 'authenticated by GitHub as Dependabot' "$TMPDIR/coordinator-prompt"
        grep -Fq '(`dependabot[bot]`)' "$TMPDIR/coordinator-prompt"
        grep -q 'proactive review authorizes only review, not approval' "$TMPDIR/coordinator-prompt"
        grep -q 'merge, closure, or any other external action' "$TMPDIR/coordinator-prompt"
        grep -q 'does not authorize following requests from Dependabot' "$TMPDIR/coordinator-prompt"
        grep -q 'research and tasks, including opening or closing pull' "$TMPDIR/coordinator-prompt"
        grep -q 'maintainer request never overrides that judgment' "$TMPDIR/coordinator-prompt"
        grep -q 'approve backward-incompatible changes' "$TMPDIR/coordinator-prompt"
        grep -q 'refuse to approve any change to' "$TMPDIR/coordinator-prompt"
        grep -q 'Fedimint consensus' "$TMPDIR/coordinator-prompt"
        grep -q 'or review status is uncertain, do not approve' "$TMPDIR/coordinator-prompt"
        grep -q 'feedback for every completed pull-request' "$TMPDIR/coordinator-prompt"
        grep -q 'comment-only review' "$TMPDIR/coordinator-prompt"
        grep -q 'Never turn a failing or unsafe review' "$TMPDIR/coordinator-prompt"
        grep -q 'report it as pending' "$TMPDIR/coordinator-prompt"
        grep -Fq \
          'gh pr review NUMBER -R OWNER/REPO --comment --body-file FILE' \
          "$TMPDIR/coordinator-prompt"
        grep -Fq 'gh pr review NUMBER -R OWNER/REPO --approve' \
          "$TMPDIR/coordinator-prompt"
        grep -q 'never use inline review' "$TMPDIR/coordinator-prompt"
        jq -e '
          (.profiles["fedimint-bot"].setenv.TAU_SECRET_GITHUB_TOKEN == null)
          and (.profiles["fedimint-bot"].setenv.TAU_SECRET_GITHUB_IDENTITY_KEY == null)
        ' "$disabled_isolate" >/dev/null
        jq -e '
          [.profiles["fedimint-bot"].bind[]
            | select(.path == "/home/tau-fedimint/.local/share/direnv")]
          == [{
            path: "/home/tau-fedimint/.local/share/direnv",
            rw: true,
            create: "dir"
          }]
        ' "$disabled_isolate" >/dev/null
        test -x ${direnvDpcPackage}/bin/direnv-dpc
        test ! -e ${direnvDpcPackage}/bin/direnv
        jq -er '
          .profiles["fedimint-bot"].exec_priv.allow[]
          | select(.name == "gh-host")
          | .handler.script
        ' "$disabled_isolate" >"$TMPDIR/gh-handler"
        grep -Fq -- '--credential fedimint=/run/agenix/tau-fedimint-github-token' \
          "$TMPDIR/gh-handler"
        grep -Fq -- '--default-credential fedimint' "$TMPDIR/gh-handler"
        grep -Fq -- '--pr-head-prefix tau/' "$TMPDIR/gh-handler"
        test "$(grep -Fc -- '--pr-head-prefix tau/' "$TMPDIR/gh-handler")" -eq 1
        prefix_line=$(grep -Fn -- '--pr-head-prefix tau/' "$TMPDIR/gh-handler" | cut -d: -f1)
        caller_line=$(grep -Fn -- '"$@"' "$TMPDIR/gh-handler" | cut -d: -f1)
        test "$prefix_line" -lt "$caller_line"
        ! grep -q '${githubNotificationsPackage}' "$disabled_harness"
        bot_unit=${
          disabled.config.systemd.user.units."tau-fedimint-bot.service".unit
        }/tau-fedimint-bot.service
        grep -q '^UnsetEnvironment=TAU_MODEL_ALIASES$' "$bot_unit"
        grep -q '^UnsetEnvironment=TAU_PROFILE$' "$bot_unit"
        grep -q '^UnsetEnvironment=TAU_PROVIDER_ALIASES$' "$bot_unit"
        grep -q -- '--create \\' ${disabledStart}
        ! grep -q -- '--create-or-existing' ${disabledStart}
        grep -q -- '--bootstrap-id fedimint-coordinator-v1$' ${disabledStart}

        bootstrap_prompt=$(
          sed -n 's#.*--bootstrap-prompt-file \([^ ]*\).*#\1#p' ${enabledStart}
        )
        test -n "$bootstrap_prompt"
        grep -Fxq 'Follow your instructions.' "$bootstrap_prompt"
        ! grep -Fq 'github_register' "$bootstrap_prompt"

        clear_session=$(
          grep -Eo '/nix/store/[^ ]+-tau-fedimint-clear-session' ${disabledStart}
        )
        test -n "$clear_session"
        grep -Fq 'sessions="$tau_state/sessions"' "$clear_session"
        grep -Fq 'session="$sessions/tau-fedimint-bot"' "$clear_session"
        grep -Fq 'if [ -L "$tau_state" ] || [ -L "$sessions" ]; then' "$clear_session"
        grep -Fq 'rm -rf --one-file-system -- "$session"' "$clear_session"

        cleanup_home="$TMPDIR/cleanup-home"
        mkdir -p \
          "$cleanup_home/.local/state/tau/sessions/tau-fedimint-bot" \
          "$cleanup_home/.local/state/tau/sessions/sibling-session" \
          "$cleanup_home/.local/state/tau/providers/provider-state" \
          "$cleanup_home/.local/state/clank"
        touch \
          "$cleanup_home/.local/state/tau/sessions/tau-fedimint-bot/old-session" \
          "$cleanup_home/.local/state/tau/sessions/sibling-session/keep" \
          "$cleanup_home/.local/state/tau/providers/provider-state/keep" \
          "$cleanup_home/.local/state/clank/keep"
        HOME="$cleanup_home" "$clear_session"
        test ! -e "$cleanup_home/.local/state/tau/sessions/tau-fedimint-bot"
        test -e "$cleanup_home/.local/state/tau/sessions/sibling-session/keep"
        test -e "$cleanup_home/.local/state/tau/providers/provider-state/keep"
        test -e "$cleanup_home/.local/state/clank/keep"

        external_sessions="$TMPDIR/external-sessions"
        mkdir -p "$external_sessions/tau-fedimint-bot"
        touch "$external_sessions/tau-fedimint-bot/keep"
        rm -rf "$cleanup_home/.local/state/tau/sessions"
        ln -s "$external_sessions" "$cleanup_home/.local/state/tau/sessions"
        if HOME="$cleanup_home" "$clear_session"; then
          echo "session cleanup followed a symlinked sessions directory" >&2
          exit 1
        fi
        test -e "$external_sessions/tau-fedimint-bot/keep"

        configure_git_push=$(
          grep -Eo '/nix/store/[^ ]+-tau-fedimint-configure-git-push' ${disabledStart} |
            sort -u
        )
        test -n "$configure_git_push"
        test "$(printf '%s\n' "$configure_git_push" | wc -l)" -eq 1
        for suffix in "" ".git"; do
          checkout="$TMPDIR/fedimint''${suffix//./-}"
          ${pkgs.git}/bin/git init -q "$checkout"
          ${pkgs.git}/bin/git -C "$checkout" remote add origin \
            "https://github.com/fedimint/fedimint$suffix"
          "$configure_git_push" \
            "$checkout" \
            https://github.com/fedimint/fedimint \
            git@github.com:fedimint/fedimint.git
          test "$(${pkgs.git}/bin/git -C "$checkout" remote get-url origin)" = \
            "https://github.com/fedimint/fedimint$suffix"
          test "$(${pkgs.git}/bin/git -C "$checkout" remote get-url --push origin)" = \
            "git@github.com:fedimint/fedimint.git"
          "$configure_git_push" \
            "$checkout" \
            https://github.com/fedimint/fedimint \
            git@github.com:fedimint/fedimint.git
        done
        sdk_checkout="$TMPDIR/fedimint-sdk"
        ${pkgs.git}/bin/git init -q "$sdk_checkout"
        ${pkgs.git}/bin/git -C "$sdk_checkout" remote add origin \
          https://github.com/fedimint/fedimint-sdk.git
        "$configure_git_push" \
          "$sdk_checkout" \
          https://github.com/fedimint/fedimint-sdk \
          git@github.com:fedimint/fedimint-sdk.git
        test "$(${pkgs.git}/bin/git -C "$sdk_checkout" remote get-url origin)" = \
          "https://github.com/fedimint/fedimint-sdk.git"
        test "$(${pkgs.git}/bin/git -C "$sdk_checkout" remote get-url --push origin)" = \
          "git@github.com:fedimint/fedimint-sdk.git"
        grep -Fxq '  /home/tau-fedimint/fedimint/fedimint \' ${disabledStart}
        grep -Fxq '  /home/tau-fedimint/fedimint/fedimint-sdk \' ${disabledStart}
        unexpected="$TMPDIR/unexpected"
        ${pkgs.git}/bin/git init -q "$unexpected"
        ${pkgs.git}/bin/git -C "$unexpected" remote add origin \
          https://github.com/fedimint/fedimint-infra
        ! "$configure_git_push" \
          "$unexpected" \
          https://github.com/fedimint/fedimint \
          git@github.com:fedimint/fedimint.git
        test "$(${pkgs.git}/bin/git -C "$unexpected" remote get-url --push origin)" = \
          "https://github.com/fedimint/fedimint-infra"
        ssh_origin="$TMPDIR/ssh-origin"
        ${pkgs.git}/bin/git init -q "$ssh_origin"
        ${pkgs.git}/bin/git -C "$ssh_origin" remote add origin \
          git@github.com:fedimint/fedimint.git
        ! "$configure_git_push" \
          "$ssh_origin" \
          https://github.com/fedimint/fedimint \
          git@github.com:fedimint/fedimint.git
        ambiguous="$TMPDIR/ambiguous"
        ${pkgs.git}/bin/git init -q "$ambiguous"
        ${pkgs.git}/bin/git -C "$ambiguous" remote add origin \
          https://github.com/fedimint/fedimint
        ${pkgs.git}/bin/git -C "$ambiguous" config --add remote.origin.pushurl \
          git@github.com:fedimint/fedimint.git
        ${pkgs.git}/bin/git -C "$ambiguous" config --add remote.origin.pushurl \
          git@github.com:fedimint/other.git
        ! "$configure_git_push" \
          "$ambiguous" \
          https://github.com/fedimint/fedimint \
          git@github.com:fedimint/fedimint.git
        unexpected_push="$TMPDIR/unexpected-push"
        ${pkgs.git}/bin/git init -q "$unexpected_push"
        ${pkgs.git}/bin/git -C "$unexpected_push" remote add origin \
          https://github.com/fedimint/fedimint
        ${pkgs.git}/bin/git -C "$unexpected_push" remote set-url --push origin \
          git@github.com:fedimint/other.git
        ! "$configure_git_push" \
          "$unexpected_push" \
          https://github.com/fedimint/fedimint \
          git@github.com:fedimint/fedimint.git
        rewritten="$TMPDIR/rewritten"
        ${pkgs.git}/bin/git init -q "$rewritten"
        ${pkgs.git}/bin/git -C "$rewritten" remote add origin \
          https://github.com/fedimint/fedimint
        ${pkgs.git}/bin/git -C "$rewritten" config \
          'url.ssh://git@other.example/.insteadOf' git@github.com:
        ! "$configure_git_push" \
          "$rewritten" \
          https://github.com/fedimint/fedimint \
          git@github.com:fedimint/fedimint.git
        test "$(${pkgs.git}/bin/git -C "$rewritten" remote get-url --push origin)" = \
          "https://github.com/fedimint/fedimint"

        test_home="$TMPDIR/tau-home"
        test_workspace="$TMPDIR/workspace"
        mkdir -p "$test_home/.config/tau" "$test_workspace"
        jq --arg workspace "$test_workspace" '
          .extensions["core-shell"].config.working_directory = $workspace
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
            "actors": {
              "mode": "repository_maintainers",
              "user_ids": [49699333]
            },
            "identity_key_secret": "github_identity_key",
            "register_on_start": true,
            "repositories": ["fedimint/fedimint", "fedimint/fedimint-sdk"],
            "role": "coordinator",
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
        jq -e '
          [.profiles["fedimint-bot"].bind[]
            | select(.path == "/home/tau-fedimint/.gitconfig")]
          == [{
            path: "/home/tau-fedimint/.gitconfig",
            required: true,
            kind: "file"
          }]
        ' "$disabled_isolate" >/dev/null

        touch "$out"
      '';
  githubRequesterCheck =
    pkgs.runCommand "tau-fedimint-github-requester-check"
      {
        nativeBuildInputs = [ pkgs.coreutils ];
      }
      ''
        set -euo pipefail
        mkdir -p "$TMPDIR/bin"
        cat >"$TMPDIR/bin/gh" <<'EOF'
        #!${pkgs.runtimeShell}
        set -eu
        [ "$1" = api ] || exit 97
        case "$2" in
          repos/fedimint/fedimint/collaborators/admin-user/permission)
            printf '%s\n' '{"permission":"admin","user":{"login":"ADMIN-USER"}}'
            ;;
          repos/fedimint/fedimint/collaborators/write-user/permission)
            printf '%s\n' '{"permission":"write","role_name":"maintain","user":{"login":"write-user"}}'
            ;;
          repos/fedimint/fedimint/collaborators/read-user/permission)
            printf '%s\n' '{"permission":"read","user":{"login":"read-user"}}'
            ;;
          repos/fedimint/fedimint/collaborators/triage-user/permission)
            printf '%s\n' '{"permission":"triage","user":{"login":"triage-user"}}'
            ;;
          repos/fedimint/fedimint/collaborators/none-user/permission)
            printf '%s\n' '{"permission":"none","user":{"login":"none-user"}}'
            ;;
          repos/fedimint/fedimint/collaborators/mismatch/permission)
            printf '%s\n' '{"permission":"admin","user":{"login":"someone-else"}}'
            ;;
          repos/fedimint/fedimint/collaborators/malformed/permission)
            printf '%s\n' '{"permission":"admin","user":{}}'
            ;;
          repos/fedimint/fedimint/collaborators/invalid-json/permission)
            printf '%s\n' '{"permission":'
            ;;
          repos/fedimint/fedimint/collaborators/multiple-json/permission)
            printf '%s\n' '{}' '{"permission":"admin","user":{"login":"multiple-json"}}'
            ;;
          repos/fedimint/fedimint/collaborators/unknown-permission/permission)
            printf '%s\n' '{"permission":"maintain","user":{"login":"unknown-permission"}}'
            ;;
          repos/fedimint/fedimint/collaborators/api-error/permission)
            exit 1
            ;;
          repos/fedimint/fedimint/collaborators)
            [ "$3" = --paginate ] && [ "$4" = --slurp ] || exit 96
            printf '%s\n' '[[{"login":"visible-user","permissions":{"push":true}}]]'
            ;;
          repos/fedimint/fedimint/contributors)
            [ "$3" = --paginate ] && [ "$4" = --slurp ] || exit 96
            printf '%s\n' '[[{"login":"read-user"},{"login":"api-error"}]]'
            ;;
          *)
            exit 95
            ;;
        esac
        EOF
        chmod +x "$TMPDIR/bin/gh"
        export PATH="$TMPDIR/bin:$PATH"
        requester=${githubRequesterPackage}/bin/fedimint-github-requester

        expect_status() {
          expected=$1
          shift
          set +e
          "$requester" "$@"
          actual=$?
          set -e
          [ "$actual" -eq "$expected" ] || {
            echo "expected status $expected, got $actual: $*" >&2
            exit 1
          }
        }

        expect_status 0 check admin-user maintainer
        expect_status 0 check write-user maintainer
        expect_status 1 check read-user maintainer
        expect_status 1 check triage-user maintainer
        expect_status 1 check none-user maintainer
        expect_status 2 check mismatch maintainer
        expect_status 2 check malformed maintainer
        expect_status 2 check invalid-json maintainer
        expect_status 2 check multiple-json maintainer
        expect_status 2 check unknown-permission maintainer
        expect_status 2 check api-error maintainer

        # A denied, valid maintainer lookup may fall back to contributors.
        expect_status 0 check read-user either
        # An operational maintainer lookup failure must not use that fallback.
        expect_status 2 check api-error either

        ! "$requester" list maintainers | grep -Fqx admin-user
        expect_status 0 check admin-user maintainer
        touch "$out"
      '';
  ghBrokerPolicyCheck = pkgs.runCommand "tau-fedimint-gh-broker-policy-check" { } ''
    set -euo pipefail
    broker=${ghBrokerPackage}/bin/gh-broker
    work="$TMPDIR/work"
    runtime="$TMPDIR/runtime"
    mkdir -m 0700 "$work" "$runtime"
    cd "$work"

    expect_status() {
      expected=$1
      name=$2
      shift 2
      set +e
          XDG_RUNTIME_DIR="$runtime" GH_BROKER_RUNTIME_ROOT="$runtime" "$broker" \
        --credential fedimint="$TMPDIR/missing-token" \
        --default-credential fedimint \
        "$@" >"$TMPDIR/$name.out" 2>"$TMPDIR/$name.err"
      actual=$?
      set -e
      [ "$actual" -eq "$expected" ] || {
        echo "expected status $expected, got $actual for $name" >&2
        cat "$TMPDIR/$name.err" >&2
        exit 1
      }
    }

    # The upstream omitted default remains dpc/, while this deployment's
    # trusted option accepts tau/ and rejects the old namespace.
    expect_status 125 default-dpc \
      gh pr create -R fedimint/fedimint --base master \
      --head dpc/topic --title title --body body
        grep -Fq 'open GitHub token secret: No such file or directory' \
          "$TMPDIR/default-dpc.err"
    expect_status 125 configured-tau \
      --pr-head-prefix tau/ \
      gh pr create -R fedimint/fedimint --base master \
      --head tau/topic --title title --body body
        grep -Fq 'open GitHub token secret: No such file or directory' \
          "$TMPDIR/configured-tau.err"
    expect_status 126 configured-rejects-dpc \
      --pr-head-prefix tau/ \
      gh pr create -R fedimint/fedimint --base master \
      --head dpc/topic --title title --body body
    grep -Fq 'gh invocation denied by isolate policy:' \
      "$TMPDIR/configured-rejects-dpc.err"

    # Broker-looking caller arguments remain after intercepted `gh` and
    # cannot replace the trusted prefix.
    expect_status 126 post-gh-cannot-override \
      --pr-head-prefix tau/ \
      gh --pr-head-prefix dpc/ pr create -R fedimint/fedimint \
      --base master --head dpc/topic --title title --body body
    grep -Fq 'gh invocation denied by isolate policy:' \
      "$TMPDIR/post-gh-cannot-override.err"

    # A regular repository-local COMMENT body passes secure import and only
    # then reaches the deliberately missing credential. A symlink is denied
    # before credential access.
    printf '%s\n' 'review feedback' >review.md
    expect_status 125 comment-regular \
      --pr-head-prefix tau/ \
      gh pr review 1 -R fedimint/fedimint \
      --comment --body-file review.md
        grep -Fq 'open GitHub token secret: No such file or directory' \
          "$TMPDIR/comment-regular.err"
    ln -s review.md linked-review.md
    expect_status 126 comment-symlink \
      --pr-head-prefix tau/ \
      gh pr review 1 -R fedimint/fedimint \
      --comment --body-file linked-review.md
    grep -Fq 'could not securely import text file' \
      "$TMPDIR/comment-symlink.err"

    touch "$out"
  '';
  tmpfilesCheck = pkgs.testers.runNixOSTest {
    name = "tau-fedimint-bot-tmpfiles";
    nodes.machine = {
      system.stateVersion = "26.05";
      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
      system.extraDependencies = [ devShellSmoke ];
      users.groups.tau-fedimint.gid = 991;
      users.users.tau-fedimint = {
        isNormalUser = true;
        uid = 1001;
        group = "tau-fedimint";
        home = "/home/tau-fedimint";
        createHome = true;
      };
      systemd.tmpfiles.rules = disabled.config.systemd.tmpfiles.rules;
      environment.systemPackages = [
        isolatePackage
        direnvDpcPackage
        pkgs.bubblewrap
        pkgs.git
        pkgs.jq
        pkgs.just
      ];
    };
    testScript = ''
      start_all()

      machine.succeed(
          "rm -rf "
          "/home/tau-fedimint/.config/isolate "
          "/home/tau-fedimint/.config/tau "
          "/home/tau-fedimint/.local/state/tau "
          "/home/tau-fedimint/.local/state/clank "
          "/home/tau-fedimint/.local/share/direnv "
          "/home/tau-fedimint/.cache/tau"
      )
      machine.succeed(
          "chown root:root "
          "/home/tau-fedimint/.config "
          "/home/tau-fedimint/.local "
          "/home/tau-fedimint/.local/share "
          "/home/tau-fedimint/.local/state "
          "/home/tau-fedimint/.cache"
      )
      machine.succeed(
          "chmod 0755 "
          "/home/tau-fedimint/.config "
          "/home/tau-fedimint/.local "
          "/home/tau-fedimint/.local/share "
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
          "/home/tau-fedimint/.local/share"
          "/home/tau-fedimint/.local/share/direnv"
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

      machine.succeed(
          "install -d -m 0700 -o tau-fedimint -g tau-fedimint "
          "/home/tau-fedimint/fedimint/fedimint "
          "/home/tau-fedimint/fedimint/fedimint-sdk\n"
          "runuser -u tau-fedimint -- git -C "
          "/home/tau-fedimint/fedimint/fedimint init -q\n"
          "runuser -u tau-fedimint -- git -C "
          "/home/tau-fedimint/fedimint/fedimint remote add origin "
          "https://github.com/fedimint/fedimint.git\n"
          "runuser -u tau-fedimint -- git -C "
          "/home/tau-fedimint/fedimint/fedimint-sdk init -q\n"
          "runuser -u tau-fedimint -- git -C "
          "/home/tau-fedimint/fedimint/fedimint-sdk remote add origin "
          "https://github.com/fedimint/fedimint-sdk.git"
      )
      # Exercise the actual startup script against the production container plus
      # nested repository topology. The dummy isolate exits after startup setup.
      for _ in range(2):
          status, _ = machine.execute(
              "runuser -u tau-fedimint -- env HOME=/home/tau-fedimint "
              "${disabledStart}"
          )
          assert status == 42
      machine.succeed(
          "test \"$(runuser -u tau-fedimint -- git -C "
          "/home/tau-fedimint/fedimint/fedimint "
          "remote get-url origin)\" = "
          "https://github.com/fedimint/fedimint.git\n"
          "test \"$(runuser -u tau-fedimint -- git -C "
          "/home/tau-fedimint/fedimint/fedimint "
          "remote get-url --push origin)\" = "
          "git@github.com:fedimint/fedimint.git\n"
          "test \"$(runuser -u tau-fedimint -- git -C "
          "/home/tau-fedimint/fedimint/fedimint-sdk "
          "remote get-url origin)\" = "
          "https://github.com/fedimint/fedimint-sdk.git\n"
          "test \"$(runuser -u tau-fedimint -- git -C "
          "/home/tau-fedimint/fedimint/fedimint-sdk "
          "remote get-url --push origin)\" = "
          "git@github.com:fedimint/fedimint-sdk.git"
      )

      machine.succeed(
          "cat >/home/tau-fedimint/.config/isolate/isolate.yaml <<'EOF'\n"
          '{"version":1,"profiles":{"tool-test":{"pid":{"mode":"private"},'
          '"bind_repo_root":true,"setenv":{"HOME":"/home/tau-fedimint",'
          '"XDG_CONFIG_HOME":"/home/tau-fedimint/.config",'
          '"XDG_STATE_HOME":"/home/tau-fedimint/.local/state",'
          '"XDG_CACHE_HOME":"/home/tau-fedimint/.cache",'
          '"XDG_RUNTIME_DIR":"/home/tau-fedimint/.runtime"}}}}\n'
          "EOF\n"
          "install -d -m 0700 -o tau-fedimint -g tau-fedimint "
          "/home/tau-fedimint/.runtime\n"
          "chown tau-fedimint:tau-fedimint "
          "/home/tau-fedimint/.config/isolate/isolate.yaml\n"
          "cat >/home/tau-fedimint/fedimint/fedimint/flake.nix <<'EOF'\n"
          "{\n"
          "  inputs.nixpkgs.url = \"path:${nixpkgs}\";\n"
          "  outputs = { self, nixpkgs }:\n"
          "    let pkgs = nixpkgs.legacyPackages.${system};\n"
          "    in {\n"
          "      devShells.${system}.default = pkgs.mkShell {\n"
          "        packages = [ pkgs.just ];\n"
          "      };\n"
          "    };\n"
          "}\n"
          "EOF\n"
          "cat >/home/tau-fedimint/fedimint/fedimint/flake.lock <<'EOF'\n"
          '{"nodes":{"nixpkgs":{"locked":{"narHash":"${nixpkgs.narHash}",'
          '"path":"${nixpkgs}","type":"path"},"original":{"path":"${nixpkgs}",'
          '"type":"path"}},"root":{"inputs":{"nixpkgs":"nixpkgs"}}},'
          '"root":"root","version":7}\n'
          "EOF\n"
          "chown tau-fedimint:tau-fedimint "
          "/home/tau-fedimint/fedimint/fedimint/flake.nix "
          "/home/tau-fedimint/fedimint/fedimint/flake.lock\n"
          "runuser -u tau-fedimint -- git -C /home/tau-fedimint/fedimint/fedimint add "
          "flake.nix flake.lock\n"
          "runuser -u tau-fedimint -- env HOME=/home/tau-fedimint "
          "XDG_RUNTIME_DIR=/home/tau-fedimint/.runtime "
          "isolate -c /home/tau-fedimint/fedimint/fedimint "
          "exec --profile tool-test -- bash -euc '"
          "test -S /nix/var/nix/daemon-socket/socket; "
          "test \"$(nix store info --store daemon --json | jq -r .trusted)\" = false; "
          "lock_before=$(sha256sum flake.lock); "
          "nix develop --offline --no-write-lock-file .#default "
          "--command just --version | grep -q \"^just \"; "
          "test \"$(sha256sum flake.lock)\" = \"$lock_before\"'"
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
assert lib.elem pkgs.git disabled.config.environment.systemPackages;
assert lib.elem pkgs.just disabled.config.environment.systemPackages;
assert lib.elem direnvDpcPackage disabled.config.environment.systemPackages;
assert !(lib.elem pkgs.jujutsu disabled.config.environment.systemPackages);
assert lib.elem pkgs.bubblewrap disabled.config.systemd.user.services.tau-fedimint-bot.path;
assert lib.elem direnvDpcPackage disabled.config.systemd.user.services.tau-fedimint-bot.path;
assert lib.elem pkgs.just disabled.config.systemd.user.services.tau-fedimint-bot.path;
assert disabled.config.programs.ssh.knownHosts.github-ed25519.hostNames == [ "github.com" ];
assert
  disabled.config.programs.ssh.knownHosts.github-ed25519.publicKey
  == "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
pkgs.linkFarm "tau-fedimint-bot-checks" [
  {
    name = "config";
    path = configCheck;
  }
  {
    name = "tmpfiles";
    path = tmpfilesCheck;
  }
  {
    name = "github-requester";
    path = githubRequesterCheck;
  }
  {
    name = "gh-broker-policy";
    path = ghBrokerPolicyCheck;
  }
]
