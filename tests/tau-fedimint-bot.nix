{
  system,
  nixpkgs,
  agenix,
  module,
  tauPackage,
  isolatePackage,
  ghBrokerPackage,
  skillsSource,
  fedimintSkillsSource,
  githubNotificationsPackage,
  discordPackage ? null,
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
    if [ -n "''${TAU_FEDIMINT_TEST_CAPTURE-}" ]; then
      {
        printf '%s\0' "$PWD"
        printf '%s\0' "$HOME"
        printf '%s\0' "$XDG_CONFIG_HOME"
        printf '%s\0' "$XDG_STATE_HOME"
        printf '%s\0' "$XDG_CACHE_HOME"
        printf '%s\0' "$XDG_RUNTIME_DIR"
        printf '%s\0' "$@"
      } >"$TAU_FEDIMINT_TEST_CAPTURE"
      exit 0
    fi
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
    inherit skillsSource;
    inherit fedimintSkillsSource;
    githubTokenAgeFile = actionToken;
    sshPrivateKeyAgeFile = sshKey;
    sshAuthorizedKeys = [ "ssh-ed25519 test-only" ];
  };
  mkSystem =
    {
      githubNotifications,
      papercutGrooming ? { },
      discord ? { },
    }:
    nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        agenix.nixosModules.default
        module
        {
          system.stateVersion = "26.05";
          services.tau-fedimint-bot = common // {
            inherit githubNotifications papercutGrooming discord;
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
  papercut = mkSystem {
    githubNotifications = { };
    papercutGrooming.enable = true;
  };
  weeklyCheck =
    pkgs.runCommand "tau-weekly-summary-check"
      {
        nativeBuildInputs = [ pkgs.python3 ];
      }
      ''
        export PYTHONTZPATH=${pkgs.tzdata}/share/zoneinfo
        python3 ${./tau-weekly-summary.py} ${../bin/tau-weekly-summary.py}
        python3 ${./tau-github-collect.py} ${../bin/tau-github-collect.py}
        mkdir "$out"
      '';
  enabled = mkSystem {
    githubNotifications = {
      enable = true;
      package = githubNotificationsPackage;
      tokenAgeFile = notificationToken;
      identityKeyAgeFile = identityKey;
    };
  };
  discordSettings = {
    enable = true;
    package = if discordPackage == null then dummyPackage "tau-ext-discord" else discordPackage;
    guildId = 123456789012345678;
    channelId = 234567890123456789;
    allowedUserIds = [ 345678901234567890 ];
    senderAliases = [
      {
        user_id = 345678901234567890;
        alias = "maintainer";
      }
    ];
    displayName = "Fedimint maintainers";
    tokenAgeFile = builtins.toFile "discord-token.age" "test-only";
    identityKeyAgeFile = builtins.toFile "discord-identity.age" "test-only";
  };
  discordEnabled = mkSystem {
    githubNotifications = enabled.config.services.tau-fedimint-bot.githubNotifications;
    discord = discordSettings;
  };
  discordMissing = mkSystem {
    githubNotifications = { };
    discord.enable = true;
  };
  discordReusedSecret = mkSystem {
    githubNotifications = { };
    discord = discordSettings // {
      identityKeyAgeFile = discordSettings.tokenAgeFile;
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
        || lib.hasPrefix "Discord " assertion.message
      )
    ) systemConfig.config.assertions;
  disabledStart = disabled.config.systemd.user.services.tau-fedimint-bot.serviceConfig.ExecStart;
  githubRequesterPackage = lib.findFirst (
    package: lib.getName package == "fedimint-github-requester"
  ) (throw "fedimint-github-requester package missing") disabled.config.environment.systemPackages;
  direnvDpcPackage = lib.findFirst (
    package: lib.getName package == "direnv-dpc"
  ) (throw "direnv-dpc package missing") disabled.config.environment.systemPackages;
  fzfPackage =
    lib.findFirst (package: lib.getName package == "fzf")
      (throw "fzf package missing from the Tau bot user profile")
      disabled.config.users.users.tau-fedimint.packages;
  tauSandboxPackage =
    lib.findFirst (package: lib.getName package == "tau-fedimint-sandbox")
      (throw "tau-fedimint-sandbox package missing from the Tau bot user profile")
      disabled.config.users.users.tau-fedimint.packages;
  discordStart = discordEnabled.config.systemd.user.services.tau-fedimint-bot.serviceConfig.ExecStart;
  upstreamSkillNames = [
    "linked-specs"
    "linked-specs-updating"
    "linked-specs-review"
    "multipart-review"
    "multipart-review-architecture"
    "multipart-review-coordination"
    "multipart-review-judgment"
    "multipart-review-maintainability"
    "multipart-review-prose"
    "multipart-review-reliability"
    "multipart-review-rust-style"
    "multipart-review-skills"
  ];
  fedimintSkillNames = [
    "fedimint-codebase"
    "fedimint-development"
    "pr-submissions-checklist"
  ];
  localSkills = {
    change-description = ../.agents/skills/change-description;
    conventional-commit = ../.agents/skills/conventional-commit;
    proactive-work = ../.agents/skills/proactive-work;
    stop-slop = ../.agents/skills/stop-slop;
    task-retrospective = ../.agents/skills/task-retrospective;
    fedimint-bot-github-cli = ../.agents/skills/fedimint-bot-github-cli;
    fedimint-maintainer-requests = ../.agents/skills/fedimint-maintainer-requests;
    fedimint-pull-request-review = ../.agents/skills/fedimint-pull-request-review;
    fedimint-dependabot = ../.agents/skills/fedimint-dependabot;
    fedimint-weekly-dev-summary = ../.agents/skills/fedimint-weekly-dev-summary;
    self-pr-grooming = ../.agents/skills/self-pr-grooming;
    fedimint-bot-self-improvement = ../.agents/skills/fedimint-bot-self-improvement;
  };
  localSkillNames = builtins.attrNames localSkills;
  installedSkillNames = upstreamSkillNames ++ fedimintSkillNames ++ localSkillNames;
  fedimintSkillSources = lib.genAttrs fedimintSkillNames (
    name:
    let
      prefix = "L+ /home/tau-fedimint/.config/agents/skills/${name} - - - - ";
      rule =
        lib.findFirst (lib.hasPrefix prefix) (throw "tmpfiles rule for ${name} is missing")
          disabled.config.systemd.tmpfiles.rules;
    in
    lib.removePrefix prefix rule
  );
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
        test -n "$disabled_harness"

        papercut_harness=$(sed -n 's#.*install -m 0600 \([^ ]*harness.yaml\).*#\1#p' \
          ${papercut.config.systemd.user.services.tau-fedimint-bot.serviceConfig.ExecStart})
        discord_harness=$(sed -n 's#.*install -m 0600 \([^ ]*harness.yaml\).*#\1#p' ${discordStart})

        clear_session=$(
          grep -Eo '/nix/store/[^ ]+-tau-fedimint-clear-session' ${disabledStart}
        )
        test -n "$clear_session"

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
          test "$(${pkgs.git}/bin/git -C "$checkout" config --local --get core.sshCommand)" = \
            "${pkgs.openssh}/bin/ssh -F /home/tau-fedimint/.ssh/config"
          ${pkgs.git}/bin/git -C "$checkout" \
            -c user.name=test -c user.email=test@example.com \
            commit --allow-empty -qm initial
          worktree="$checkout-worktree"
          ${pkgs.git}/bin/git -C "$checkout" worktree add -q "$worktree"
          test "$(${pkgs.git}/bin/git -C "$worktree" config --local --get core.sshCommand)" = \
            "${pkgs.openssh}/bin/ssh -F /home/tau-fedimint/.ssh/config"
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
        test "$(${pkgs.git}/bin/git -C "$sdk_checkout" config --local --get core.sshCommand)" = \
          "${pkgs.openssh}/bin/ssh -F /home/tau-fedimint/.ssh/config"
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
        test_project="$test_workspace/project"
        test_workdir="$test_project/subdir"
        mkdir -p \
          "$test_home/.config/tau" \
          "$test_home/.config/agents/skills" \
          "$test_project/.agents/skills/project-subdir-test" \
          "$test_workdir"
        cat >"$test_project/AGENTS.md" <<'EOF'
        PROJECT_SUBDIR_AGENTS_MARKER
        EOF
        cat >"$test_project/.agents/skills/project-subdir-test/SKILL.md" <<'EOF'
        ---
        name: project-subdir-test
        description: Test skill discovered from an ancestor of the configured workdir.
        ---

        PROJECT_SUBDIR_SKILL_MARKER
        EOF
        for name in ${lib.escapeShellArgs upstreamSkillNames}; do
          ln -s "${skillsSource}/skills/$name" \
            "$test_home/.config/agents/skills/$name"
        done
        ${lib.concatMapStringsSep "\n" (name: ''
          ln -s "${fedimintSkillSources.${name}}" \
            "$test_home/.config/agents/skills/${name}"
        '') fedimintSkillNames}
        ${lib.concatMapStringsSep "\n" (name: ''
          ln -s "${localSkills.${name}}" \
            "$test_home/.config/agents/skills/${name}"
        '') localSkillNames}
        jq --arg workspace "$test_workspace" --arg workdir "$test_workdir" '
          .extensions["core-shell"].config.working_directory = $workdir
          | .inter_session.allow_project_roots = [$workspace, ($workspace + "/**")]
        ' "$disabled_harness" >"$test_home/.config/tau/harness.yaml"
        jq -er '[.agents.role_groups[].roles | keys[]] | sort | unique | .[]' \
          "$disabled_harness" >"$TMPDIR/roles"
        while IFS= read -r role; do
          skills="$TMPDIR/$role-skills"
          env -u TAU_PROFILE -u TAU_PROVIDER_ALIASES -u TAU_MODEL_ALIASES \
            HOME="$test_home" \
            XDG_CONFIG_HOME="$test_home/.config" \
            XDG_STATE_HOME="$test_home/.local/state" \
            XDG_CACHE_HOME="$test_home/.cache" \
            ${tauPackage}/bin/tau --role "$role" \
              dev print-skills --format json >"$skills"
          jq -e --argjson expected '${builtins.toJSON installedSkillNames}' '
            ([.[].name] | sort) as $actual
            | ($expected | sort) as $expected
            | (($expected - $actual) | length == 0)
            and ($actual | index("project-subdir-test") != null)
            and ($actual | index("linked-specs-grooming") == null)
            and ($actual | index("github-cli") == null)
            and ($actual | index("tau-self-knowledge-tracing") != null)
            and ($actual | index("tau-self-knowledge-cache") != null)
            and ($actual | index("tau-self-knowledge-debugging") != null)
          ' "$skills" >/dev/null
          provider_prompt="$TMPDIR/$role-provider-prompt"
          env -u TAU_PROFILE -u TAU_PROVIDER_ALIASES -u TAU_MODEL_ALIASES \
            HOME="$test_home" \
            XDG_CONFIG_HOME="$test_home/.config" \
            XDG_STATE_HOME="$test_home/.local/state" \
            XDG_CACHE_HOME="$test_home/.cache" \
            ${tauPackage}/bin/tau --role "$role" dev print-prompt >"$provider_prompt"
          for name in ${lib.escapeShellArgs fedimintSkillNames}; do
            grep -Fq "<name>$name</name>" "$provider_prompt"
          done
          grep -Fq 'PROJECT_SUBDIR_AGENTS_MARKER' "$provider_prompt"
          grep -Fq '<name>project-subdir-test</name>' "$provider_prompt"
          if [ "$role" = editor ]; then
            env -u TAU_PROFILE HOME="$test_home" \
              XDG_CONFIG_HOME="$test_home/.config" \
              XDG_STATE_HOME="$test_home/.local/state" \
              XDG_CACHE_HOME="$test_home/.cache" \
              ${tauPackage}/bin/tau --role editor dev print-tools \
                >"$TMPDIR/editor-tools"
            ! grep -q 'agent_start' "$TMPDIR/editor-tools"
          fi
        done <"$TMPDIR/roles"
        # Use the pinned harness's actual extension declarations and role policy.
        # Tool previews do not invoke grooming or require provider credentials.
        jq --arg workspace "$test_workspace" --arg workdir "$test_workdir" '
          .extensions["core-shell"].config.working_directory = $workdir
          | .inter_session.allow_project_roots = [$workspace, ($workspace + "/**")]
        ' "$papercut_harness" >"$test_home/.config/tau/harness.yaml"
        while IFS= read -r role; do
          env -u TAU_PROFILE -u TAU_PROVIDER_ALIASES -u TAU_MODEL_ALIASES \
            HOME="$test_home" \
            XDG_CONFIG_HOME="$test_home/.config" \
            XDG_STATE_HOME="$test_home/.local/state" \
            XDG_CACHE_HOME="$test_home/.cache" \
            ${tauPackage}/bin/tau --role "$role" dev print-tools >"$TMPDIR/papercut-$role-tools"
          if [ "$role" = coordinator ]; then
            for tool in papercut_list papercut_read papercut_archive; do
              grep -q "$tool" "$TMPDIR/papercut-$role-tools"
            done
          else
            ! grep -Eq 'papercut_(list|read|archive)' "$TMPDIR/papercut-$role-tools"
          fi
        done <"$TMPDIR/roles"
        for reference in phrases structures examples; do
          test -s "$test_home/.config/agents/skills/stop-slop/references/$reference.md"
        done
        test -s "$test_home/.config/agents/skills/stop-slop/LICENSE"

        ${lib.optionalString (discordPackage != null) ''
          # Exercise the real extension's scoped declarations and effective
          # role grants, with null config and no secrets: no Discord transport.
          jq --arg workspace "$test_workspace" --arg workdir "$test_workdir" '
            .extensions["maintainer-discord"].config = null
            | .extensions["maintainer-discord"].secrets = {}
            | del(.extensions["github-notifications"])
            | .extensions["core-shell"].config.working_directory = $workdir
            | .inter_session.allow_project_roots = [$workspace, ($workspace + "/**")]
          ' "$discord_harness" >"$test_home/.config/tau/harness.yaml"
          while IFS= read -r role; do
            env -u TAU_PROFILE HOME="$test_home" \
              XDG_CONFIG_HOME="$test_home/.config" \
              XDG_STATE_HOME="$test_home/.local/state" \
              XDG_CACHE_HOME="$test_home/.cache" \
              ${tauPackage}/bin/tau --role "$role" dev print-tools >"$TMPDIR/discord-$role-tools"
            env -u TAU_PROFILE HOME="$test_home" \
              XDG_CONFIG_HOME="$test_home/.config" \
              XDG_STATE_HOME="$test_home/.local/state" \
              XDG_CACHE_HOME="$test_home/.cache" \
              ${tauPackage}/bin/tau --role "$role" dev print-system-prompt >"$TMPDIR/discord-$role-prompt"
            if [ "$role" = coordinator ]; then
              printf '%s\n' maintainer_discord_conversations \
                maintainer_discord_register maintainer_discord_send >"$TMPDIR/expected-discord-tools"
              grep -oE 'maintainer_discord_[a-z_]+' "$TMPDIR/discord-$role-tools" |
                sort -u >"$TMPDIR/actual-discord-tools"
              cmp "$TMPDIR/expected-discord-tools" "$TMPDIR/actual-discord-tools"
            else
              ! grep -q 'maintainer_discord' "$TMPDIR/discord-$role-tools"
              ! grep -q 'maintainer_discord' "$TMPDIR/discord-$role-prompt"
            fi
          done <"$TMPDIR/roles"
          cp "$disabled_harness" "$test_home/.config/tau/harness.yaml"
        ''}

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
          repos/fedimint/fedimint/collaborators)
            [ "$3" = --paginate ] && [ "$4" = --slurp ] || exit 96
            printf '%s\n' '[[{"login":"visible-user","permissions":{"push":true}},{"login":"reader","permissions":{"push":false}}]]'
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

        "$requester" list maintainers | grep -Fqx visible-user
        ! "$requester" list maintainers | grep -Fqx reader
        "$requester" list contributors | grep -Fqx read-user
        expect_status 0 check read-user contributor
        expect_status 1 check missing-user contributor
        expect_status 64 check visible-user maintainer
        touch "$out"
      '';
  githubToolRegistrationTest = pkgs.writeText "tau-fedimint-github-tool-registration.py" ''
    import os
    import subprocess
    import sys
    import queue
    import signal
    import threading

    import cbor2

    executable = sys.argv[1]
    lookup_enabled = sys.argv[2] == "enabled"
    signal.alarm(30)

    def decode_messages(stream):
        # cbor2 5.8 reads ahead: keep one decoder for the entire CBOR sequence.
        decoder = cbor2.CBORDecoder(stream)
        while True:
            yield decoder.decode()

    # Batch frames into one pipe write so the decoder must retain read-ahead.
    burst = [
        {"message": "hello", "payload": {}},
        {"message": "emit", "payload": {"event": {"event": "tool.registration_declared"}}},
        {"message": "ready", "payload": {}},
    ]
    read_fd, write_fd = os.pipe()
    os.write(write_fd, b"".join(cbor2.dumps(message) for message in burst))
    os.close(write_fd)
    with os.fdopen(read_fd, "rb", buffering=0) as stream:
        messages = decode_messages(stream)
        assert [next(messages) for _ in burst] == burst

    def registrations(lookup_enabled):
        process = subprocess.Popen(
            [executable],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            bufsize=0,
        )
        messages = queue.Queue()

        def read_messages():
            try:
                for message in decode_messages(process.stdout):
                    messages.put(message)
            except BaseException as error:
                messages.put(error)

        threading.Thread(target=read_messages, daemon=True).start()

        hello = messages.get(timeout=10)
        if isinstance(hello, BaseException):
            raise hello
        assert hello["message"] == "hello"
        assert hello["payload"]["protocol_version"] == {"major": 14, "minor": 0}
        config = {
            "token_secret": "github_token",
            "identity_key_secret": "github_identity_key",
            "repositories": ["fedimint/fedimint", "fedimint/fedimint-sdk", "fedimint/fedimint-infra"],
            "actors": {
                "mode": "repository_maintainers",
                "user_ids": [49699333],
            },
            "activity_filters": {
                "require_comment_mention": True,
                "direct_review_requests_only": True,
            },
            "identity_context": {
                "delivery": True,
                "lookup_tool": lookup_enabled,
                "cache_seconds": 300,
            },
            "register_on_start": True,
            "role": "coordinator",
        }
        cbor2.dump(
            {
                "message": "configure",
                "payload": {
                    # Match the pinned core and independently pinned extension.
                    "harness_protocol_version": {"major": 14, "minor": 0},
                    "absent_optional_secrets": [],
                    "config": config,
                    "instance_name": "github-notifications",
                    "secrets": {
                        "github_token": "fixture",
                        "github_identity_key": "00" * 32,
                    },
                    "settings_files": {},
                },
            },
            process.stdin,
        )
        process.stdin.flush()
        tools = []
        ready = False
        while not ready:
            message = messages.get(timeout=10)
            if isinstance(message, BaseException):
                raise message
            if message["message"] == "emit":
                event = message["payload"]["event"]
                if event["event"] == "tool.registration_declared":
                    tools.append(event["payload"]["tool"])
            if message["message"] == "ready":
                ready = True
        process.kill()
        process.wait(timeout=5)
        return tools

    tools = registrations(lookup_enabled)
    if lookup_enabled:
        assert [tool["name"] for tool in tools] == [
            "github_register",
            "github_user_context",
        ]
        assert [tool["model_visible_name"] for tool in tools] == [
            "github_register",
            "github_user_context",
        ]
        context = tools[1]
        assert context["enabled_by_default"] is False
        assert context["parameters"] == {
            "type": "object",
            "properties": {
                "username": {"type": "string", "minLength": 1, "maxLength": 80}
            },
            "required": ["username"],
            "additionalProperties": False,
        }
    else:
        assert [tool["name"] for tool in tools] == ["github_register"], tools
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

    expect_supported() {
      name=$1
      shift
      expect_status 125 "$name" "$@"
      grep -Fq 'open GitHub token secret: No such file or directory' \
        "$TMPDIR/$name.err"
    }

    # Infra uses the same scoped credential and PR namespace, not a new broker.
    expect_supported infra-pr-create --pr-head-prefix tau/ \
      gh pr create -R fedimint/fedimint-infra --base main \
      --head tau/self-improvement --title title --body body
    expect_supported infra-pr-list \
      gh pr list -R fedimint/fedimint-infra --author fedimint-tau --state open

    expect_denied() {
      name=$1
      shift
      expect_status 126 "$name" "$@"
      grep -Fq 'gh invocation denied by isolate policy:' "$TMPDIR/$name.err"
      ! grep -Fq 'open GitHub token secret' "$TMPDIR/$name.err"
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

    # Newly pinned reaction and standalone line-comment grammars pass policy
    # validation before the deliberately absent credential is opened.
    expect_status 125 reaction-root \
      gh api -X POST repos/fedimint/fedimint/issues/42/reactions \
      -f content=+1 --jq '{id,content,user:.user.login}'
    grep -Fq 'open GitHub token secret: No such file or directory' \
      "$TMPDIR/reaction-root.err"
    expect_status 125 reaction-conversation-comment \
      gh api -X POST repos/fedimint/fedimint/issues/comments/5803800022/reactions \
      -f content=eyes --jq '{id,content,user:.user.login}'
    grep -Fq 'open GitHub token secret: No such file or directory' \
      "$TMPDIR/reaction-conversation-comment.err"
    expect_status 125 reaction-review-comment \
      gh api -X POST repos/fedimint/fedimint/pulls/comments/5803800022/reactions \
      -f content=heart --jq '{id,content,user:.user.login}'
    grep -Fq 'open GitHub token secret: No such file or directory' \
      "$TMPDIR/reaction-review-comment.err"
    expect_status 125 line-comment \
      gh api -X POST repos/fedimint/fedimint/pulls/42/comments \
      -f body='Use the validated value.' \
      -f commit_id=0123456789abcdef0123456789abcdef01234567 \
      -f path=src/policy.rs -f line=42 -f side=RIGHT \
      --jq '{id,path,line,side,url:.html_url}'
    grep -Fq 'open GitHub token secret: No such file or directory' \
      "$TMPDIR/line-comment.err"

    # Invalid enums, typed caller fields, and non-canonical lines remain local
    # policy denials and expose the supported grammar without credential access.
    expect_status 126 reaction-sad-face \
      gh api -X POST repos/fedimint/fedimint/issues/42/reactions \
      -f content=sad-face
    grep -Fq 'gh invocation denied by isolate policy:' \
      "$TMPDIR/reaction-sad-face.err"
    grep -Fq 'documented endpoint families and options' \
      "$TMPDIR/reaction-sad-face.err"
    expect_status 126 line-comment-typed \
      gh api -X POST repos/fedimint/fedimint/pulls/42/comments \
      -f body='Use the validated value.' \
      -f commit_id=0123456789abcdef0123456789abcdef01234567 \
      -f path=src/policy.rs -F line=42 -f side=RIGHT
    grep -Fq 'gh invocation denied by isolate policy:' \
      "$TMPDIR/line-comment-typed.err"
    grep -Fq 'Typed API fields are unsupported' \
      "$TMPDIR/line-comment-typed.err"
    expect_status 126 line-comment-leading-zero \
      gh api -X POST repos/fedimint/fedimint/pulls/42/comments \
      -f body='Use the validated value.' \
      -f commit_id=0123456789abcdef0123456789abcdef01234567 \
      -f path=src/policy.rs -f line=042 -f side=RIGHT
    grep -Fq 'documented endpoint families and options' \
      "$TMPDIR/line-comment-leading-zero.err"

    # Exercise the pinned collaboration policy against a missing-token fixture.
    # Accepted operations reach credential opening; denied neighbors stay local.
    expect_supported pr-close \
      gh pr close 9195 -R fedimint/fedimint
    expect_supported pr-reopen \
      gh pr reopen 9195 -R fedimint/fedimint
    expect_supported issue-close \
      gh issue close 42 -R fedimint/fedimint --reason 'not planned'
    expect_supported issue-reopen \
      gh issue reopen 42 -R fedimint/fedimint
    expect_supported pr-ready \
      gh pr ready 42 -R fedimint/fedimint
    expect_supported pr-draft \
      gh pr ready 42 -R fedimint/fedimint --undo
    expect_supported issue-inline-comment \
      gh issue comment 42 -R fedimint/fedimint --body reply
    expect_supported issue-inline-edit \
      gh issue edit 42 -R fedimint/fedimint --body updated
    expect_supported pr-label \
      gh pr edit 42 -R fedimint/fedimint --add-label bug
    expect_supported pr-assignee \
      gh pr edit 42 -R fedimint/fedimint --add-assignee octocat
    expect_supported pr-reviewer \
      gh pr edit 42 -R fedimint/fedimint --add-reviewer octocat
    expect_supported comment-read \
      gh api repos/fedimint/fedimint/issues/comments/5803800022
    expect_supported files-read \
      gh api repos/fedimint/fedimint/pulls/42/files --paginate
    printf '%s\n' 'request changes' >request-changes.md
    expect_supported request-changes \
      gh pr review 42 -R fedimint/fedimint \
      --request-changes --body-file request-changes.md
    expect_supported own-comment-edit \
      gh api --method PATCH \
      repos/fedimint/fedimint/issues/comments/5803800022 \
      --raw-field body=corrected

    expect_denied comment-delete \
      gh pr comment 42 -R fedimint/fedimint --delete-last --yes
    expect_denied pr-merge \
      gh pr merge 42 -R fedimint/fedimint
    expect_denied arbitrary-api \
      gh api --method DELETE \
      repos/fedimint/fedimint/issues/comments/5803800022

    touch "$out"
  '';
  tmpfilesCheck = pkgs.testers.runNixOSTest {
    name = "tau-fedimint-bot-tmpfiles";
    nodes.machine = {
      system.stateVersion = "26.05";
      virtualisation.memorySize = 4096;
      services.resolved.enable = true;
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
        packages = disabled.config.users.users.tau-fedimint.packages;
      };
      systemd.tmpfiles.rules = disabled.config.systemd.tmpfiles.rules;
      environment.systemPackages = [
        (lib.findFirst (
          p: (p.name or "") == "agent-browser"
        ) (throw "missing agent-browser") disabled.config.environment.systemPackages)
        isolatePackage
        direnvDpcPackage
        pkgs.bubblewrap
        pkgs.git
        pkgs.gnupg
        pkgs.jq
        pkgs.just
        (pkgs.python3.withPackages (python: [
          python.cbor2
          python.pillow
        ]))
        pkgs.ripgrep
        githubNotificationsPackage
      ];
    };
    testScript = ''
      import shlex

      start_all()

      registration_status, registration_output = machine.execute(
          "python ${githubToolRegistrationTest} "
          "${githubNotificationsPackage}/bin/tau-ext-github enabled 2>&1 && "
          "python ${githubToolRegistrationTest} "
          "${githubNotificationsPackage}/bin/tau-ext-github disabled 2>&1"
      )
      assert registration_status == 0, registration_output

      machine.succeed(
          "rm -rf "
          "/tmp/public "
          "/tmp/public-target "
          "/home/tau-fedimint/.config/isolate "
          "/home/tau-fedimint/.config/agents "
          "/home/tau-fedimint/.config/tau "
          "/home/tau-fedimint/.ssh "
          "/home/tau-fedimint/.local/state/tau "
          "/home/tau-fedimint/.local/state/clank "
          "/home/tau-fedimint/.local/share/direnv "
          "/home/tau-fedimint/.cache/tau"
      )
      machine.succeed("install -d -m 0755 /home/tau-fedimint/.ssh")
      machine.succeed(
          "chown root:root "
          "/home/tau-fedimint/.config "
          "/home/tau-fedimint/.ssh "
          "/home/tau-fedimint/.local "
          "/home/tau-fedimint/.local/share "
          "/home/tau-fedimint/.local/state "
          "/home/tau-fedimint/.cache"
      )
      machine.succeed(
          "chmod 0755 "
          "/home/tau-fedimint/.config "
          "/home/tau-fedimint/.ssh "
          "/home/tau-fedimint/.local "
          "/home/tau-fedimint/.local/share "
          "/home/tau-fedimint/.local/state "
          "/home/tau-fedimint/.cache"
      )

      machine.succeed(
          "install -d -m 0700 /tmp/public-target && "
          "ln -s /tmp/public-target /tmp/public"
      )
      machine.succeed("systemd-tmpfiles --create")
      # Simulate an upgrade from the old bot-managed generic skill name.
      machine.succeed(
          "ln -s ${localSkills.fedimint-bot-github-cli} "
          "/home/tau-fedimint/.config/agents/skills/github-cli && "
          "systemd-tmpfiles --remove --create && "
          "test ! -L /home/tau-fedimint/.config/agents/skills/github-cli"
      )
      machine.succeed(
          "set -e; "
          "for name in ${lib.escapeShellArgs installedSkillNames}; do "
          "test -L \"/home/tau-fedimint/.config/agents/skills/$name\"; "
          "test -f \"/home/tau-fedimint/.config/agents/skills/$name/SKILL.md\"; "
          "done; "
          "test ! -e /home/tau-fedimint/.config/agents/skills/linked-specs-grooming"
      )
      machine.succeed(
          "test -L /tmp/public && "
          "test \"$(stat -Lc '%u:%g:%a' /tmp/public-target)\" = 0:0:700"
      )
      machine.succeed(
          "rm /tmp/public && systemd-tmpfiles --create && "
          "test \"$(stat -c '%u:%g:%a' /tmp/public)\" = 65534:65534:1733"
      )
      machine.fail("runuser -u tau-fedimint -- ls /tmp/public")
      machine.succeed(
          "runuser -l tau-fedimint -c '"
          "test \"$(readlink -f \"$(command -v fzf)\")\" = \"${fzfPackage}/bin/fzf\" && "
          "fzf --version >/dev/null'"
      )
      machine.succeed(
          "runuser -u tau-fedimint -- sh -euc '"
          "artifact=$(mktemp /tmp/public/host-artifact-XXXXXX); "
          "printf shared >\"$artifact\"; "
          "test \"$(cat \"$artifact\")\" = shared; "
          "rm \"$artifact\"'"
      )

      for path in ${
        builtins.toJSON [
          "/home/tau-fedimint/fedimint"
          "/home/tau-fedimint/.config"
          "/home/tau-fedimint/.config/isolate"
          "/home/tau-fedimint/.config/tau"
          "/home/tau-fedimint/.ssh"
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
          "/home/tau-fedimint/fedimint/fedimint-sdk "
          "/home/tau-fedimint/fedimint/fedimint-infra\n"
          "runuser -u tau-fedimint -- git -C "
          "/home/tau-fedimint/fedimint/fedimint-infra init -q\n"
          "runuser -u tau-fedimint -- git -C "
          "/home/tau-fedimint/fedimint/fedimint-infra remote add origin "
          "https://github.com/fedimint/fedimint-infra.git\n"
          "runuser -u tau-fedimint -- sh -c "
          "'printf preserve > /home/tau-fedimint/fedimint/fedimint-infra/unfinished'\n"
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
          "test \"$(cat /home/tau-fedimint/fedimint/fedimint-infra/unfinished)\" = preserve\n"
          "test \"$(runuser -u tau-fedimint -- git -C "
          "/home/tau-fedimint/fedimint/fedimint-infra remote get-url origin)\" = "
          "https://github.com/fedimint/fedimint-infra.git\n"
          "test \"$(runuser -u tau-fedimint -- git -C "
          "/home/tau-fedimint/fedimint/fedimint-infra remote get-url --push origin)\" = "
          "git@github.com:fedimint/fedimint-infra.git"
      )
      # Use the real supervised shell, not just the outer isolate: hidden Tau
      # state must remain hidden while private grooming bookkeeping is writable.
      bot_env = (
          "env HOME=/home/tau-fedimint "
          "PATH=/run/current-system/sw/bin:/etc/profiles/per-user/tau-fedimint/bin "
          "XDG_CONFIG_HOME=/home/tau-fedimint/.config "
          "XDG_STATE_HOME=/home/tau-fedimint/.local/state "
          "XDG_RUNTIME_DIR=/run/user/1001 "
      )
      tau = "runuser -u tau-fedimint -- " + bot_env + "${tauPackage}/bin/tau "
      state = "/home/tau-fedimint/.local/state/tau"
      machine.succeed(
          "install -d -m 0700 -o tau-fedimint -g tau-fedimint "
          "/run/user/1001\n"
          "runuser -u tau-fedimint -- mkdir -p " + state + "/ext/std-utils\n"
          "systemd-run --unit=tau-grooming-shell-test --uid=tau-fedimint "
          "--property=WorkingDirectory=/home/tau-fedimint/fedimint "
          + bot_env + "${tauPackage}/bin/tau serve "
          "--session grooming-shell-test --create --mirror-extension-stderr"
      )
      try:
          machine.wait_until_succeeds(
              tau + "session list --json | grep -q grooming-shell-test", timeout=30
          )
      except Exception:
          print(machine.succeed("journalctl -u tau-grooming-shell-test --no-pager"))
          raise
      machine.succeed(
          tau + "dev send grooming-shell-test "
          + shlex.quote(
              "!!core-shell set -eu; umask 077; "
              f"test ! -e {state}/ext/std-utils; "
              f"if mkdir {state}/papercut-grooming 2>/dev/null; then exit 1; fi; "
              f"mkdir -p {state}/ext/core-shell/papercut-grooming; "
              f"private_dir=$(mktemp -d {state}/ext/core-shell/papercut-grooming/sweep.XXXXXXXX); "
              'printf complete >"$private_dir/snapshot.md"; '
              'test "$(cat "$private_dir/snapshot.md")" = complete; '
              'test "$(stat -c %a "$private_dir")" = 700; '
              'test "$(stat -c %a "$private_dir/snapshot.md")" = 600; '
              f"printf passed >{state}/ext/core-shell/grooming-shell-check"
          )
      )
      # A successful dev send is only delivery acceptance; await the shell's
      # completed checks rather than treating that acknowledgement as success.
      machine.wait_until_succeeds(
          f"test \"$(cat {state}/ext/core-shell/grooming-shell-check)\" = passed"
      )
      machine.succeed("systemctl stop tau-grooming-shell-test")
      machine.fail("${tauSandboxPackage}/bin/tau-fedimint-sandbox --version")
      machine.succeed(
          "set -eu\n"
          "capture=/tmp/tau-sandbox-args\n"
          "expected=/tmp/tau-sandbox-expected\n"
          "runuser -u tau-fedimint -- env "
          "HOME=/tmp/wrong-home "
          "XDG_CONFIG_HOME=/tmp/wrong-config "
          "XDG_STATE_HOME=/tmp/wrong-state "
          "XDG_CACHE_HOME=/tmp/wrong-cache "
          "XDG_RUNTIME_DIR=/tmp/wrong-runtime "
          "TAU_FEDIMINT_TEST_CAPTURE=\"$capture\" "
          "${tauSandboxPackage}/bin/tau-fedimint-sandbox "
          "--role 'coordinator role' \"\" '*' >/dev/null\n"
          "printf '%s\\0' "
          "'/home/tau-fedimint/fedimint' "
          "'/home/tau-fedimint' "
          "'/home/tau-fedimint/.config' "
          "'/home/tau-fedimint/.local/state' "
          "'/home/tau-fedimint/.cache' "
          "'/run/user/1001' "
          "'exec' '--profile' 'fedimint-bot' '--' "
          "'${tauPackage}/bin/tau' "
          "'--role' 'coordinator role' \"\" '*' >\"$expected\"\n"
          "cmp \"$expected\" \"$capture\""
      )
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
          "git@github.com:fedimint/fedimint-sdk.git\n"
          "test \"$(stat -c '%u:%g:%a' /home/tau-fedimint/.ssh/config)\" = "
          "1001:991:600\n"
          "test \"$(runuser -u tau-fedimint -- git -C "
          "/home/tau-fedimint/fedimint/fedimint "
          "config --local --get core.sshCommand)\" = "
          "'${pkgs.openssh}/bin/ssh -F /home/tau-fedimint/.ssh/config'\n"
          "test \"$(runuser -u tau-fedimint -- git -C "
          "/home/tau-fedimint/fedimint/fedimint-sdk "
          "config --local --get core.sshCommand)\" = "
          "'${pkgs.openssh}/bin/ssh -F /home/tau-fedimint/.ssh/config'"
      )
      # Use the unmodified generated production profile, the real isolate, and
      # the bot UID. Supply only a credential-free SSH socket for its required
      # mount; browser commands never leave the sandbox.
      machine.succeed(
          "install -d -m 0700 -o tau-fedimint -g tau-fedimint /run/user/1001\n"
          "runuser -u tau-fedimint -- ${pkgs.openssh}/bin/ssh-agent "
          "-a /run/user/1001/tau-fedimint-ssh-agent.sock\n"
          "runuser -u tau-fedimint -- env HOME=/home/tau-fedimint "
          "XDG_RUNTIME_DIR=/run/user/1001 "
          "timeout -k 5 120 isolate -c /home/tau-fedimint/fedimint "
          "exec --profile fedimint-bot -- "
          "bash ${./tau-agent-browser-smoke.sh}",
          timeout=150,
      )
      machine.succeed(
          "timeout -k 5 60 python ${./tau-scratch-cleanup.py} "
          "${pkgs.writeText "tau-scratch-tmpfiles.conf" (lib.concatStringsSep "\n" disabled.config.systemd.tmpfiles.rules)}",
          timeout=75,
      )
      machine.succeed(
          "set -e\n"
          "cp /home/tau-fedimint/.config/isolate/isolate.yaml "
          "/home/tau-fedimint/.config/isolate/isolate.yaml.saved\n"
          "jq '.profiles[\"fedimint-bot\"].bind |= map(select("
          ".path == \"/home/tau-fedimint/fedimint\" or "
          ".path == \"/tmp/public\" or "
          ".path == \"/home/tau-fedimint/.config/agents\"))' "
          "/home/tau-fedimint/.config/isolate/isolate.yaml "
          ">/home/tau-fedimint/.config/isolate/isolate.yaml.new\n"
          "mv /home/tau-fedimint/.config/isolate/isolate.yaml.new "
          "/home/tau-fedimint/.config/isolate/isolate.yaml\n"
          "chown tau-fedimint:tau-fedimint "
          "/home/tau-fedimint/.config/isolate/isolate.yaml\n"
          "install -d -m 0700 -o tau-fedimint -g tau-fedimint "
          "/home/tau-fedimint/.runtime\n"
          "runuser -u tau-fedimint -- env HOME=/home/tau-fedimint "
          "XDG_RUNTIME_DIR=/home/tau-fedimint/.runtime "
          "isolate -c /home/tau-fedimint/fedimint "
          "exec --profile fedimint-bot -- bash -euc '"
          "for name in ${lib.escapeShellArgs installedSkillNames}; do "
          "test -f \"/home/tau-fedimint/.config/agents/skills/$name/SKILL.md\"; "
          "done'\n"
          "mv /home/tau-fedimint/.config/isolate/isolate.yaml.saved "
          "/home/tau-fedimint/.config/isolate/isolate.yaml"
      )

      # Reproduce the overflow-owner failure, then run Git's real configured
      # SSH transport in the same isolate. Port 1 is deliberately closed:
      # reaching connect(2) proves OpenSSH accepted the bot-owned -F config.
      machine.succeed(
          "cp /home/tau-fedimint/.config/isolate/isolate.yaml "
          "/home/tau-fedimint/.config/isolate/isolate.yaml.saved\n"
          "printf 'Host *\\n' "
          ">/home/tau-fedimint/fedimint/root-owned-ssh-config\n"
          "chmod 0444 /home/tau-fedimint/fedimint/root-owned-ssh-config\n"
          "printf 'Include "
          "/home/tau-fedimint/fedimint/root-owned-ssh-config\\n' "
          ">/home/tau-fedimint/fedimint/negative-ssh-config\n"
          "chown tau-fedimint:tau-fedimint "
          "/home/tau-fedimint/fedimint/negative-ssh-config\n"
          "chmod 0600 /home/tau-fedimint/fedimint/negative-ssh-config\n"
          "jq '.profiles[\"fedimint-bot\"].bind |= map(select("
          ".path == \"/home/tau-fedimint/fedimint\" or "
          ".path == \"/tmp/public\" or "
          ".path == \"/home/tau-fedimint/.gitconfig\" or "
          ".path == \"/home/tau-fedimint/.ssh/config\"))' "
          "/home/tau-fedimint/.config/isolate/isolate.yaml "
          ">/home/tau-fedimint/.config/isolate/isolate.yaml.new\n"
          "mv /home/tau-fedimint/.config/isolate/isolate.yaml.new "
          "/home/tau-fedimint/.config/isolate/isolate.yaml\n"
          "chown tau-fedimint:tau-fedimint "
          "/home/tau-fedimint/.config/isolate/isolate.yaml\n"
          "install -d -m 0700 -o tau-fedimint -g tau-fedimint "
          "/home/tau-fedimint/.runtime\n"
          "runuser -u tau-fedimint -- env HOME=/home/tau-fedimint "
          "XDG_RUNTIME_DIR=/home/tau-fedimint/.runtime "
          "isolate -c /home/tau-fedimint/fedimint "
          "exec --profile fedimint-bot -- bash -euc '"
          "cd /home/tau-fedimint/fedimint/fedimint; "
          "set +e; "
          "bad_output=$(git -c core.sshCommand=\"${pkgs.openssh}/bin/ssh "
          "-F /home/tau-fedimint/fedimint/negative-ssh-config\" "
          "ls-remote ssh://git@127.0.0.1:1/unused 2>&1); "
          "bad_status=$?; "
          "set -e; "
          "test \"$bad_status\" -ne 0; "
          "printf \"%s\\n\" \"$bad_output\" | grep -F "
          "\"Bad owner or permissions\"; "
          "git init -q /home/tau-fedimint/fedimint/new-ssh-checkout; "
          "for directory in /home/tau-fedimint/fedimint "
          "/home/tau-fedimint/fedimint/new-ssh-checkout; do "
          "cd \"$directory\"; "
          "set +e; "
          "output=$(GIT_TRACE=1 git ls-remote ssh://git@127.0.0.1:1/unused 2>&1); "
          "status=$?; "
          "set -e; "
          "test \"$status\" -ne 0; "
          "printf \"%s\\n\" \"$output\" | grep -F "
          "\"${pkgs.openssh}/bin/ssh -F /home/tau-fedimint/.ssh/config\"; "
          "printf \"%s\\n\" \"$output\" | grep -F \"Connection refused\"; "
          "! printf \"%s\\n\" \"$output\" | grep -F \"Bad owner or permissions\"; "
          "done; "
          "rm -rf /home/tau-fedimint/fedimint/new-ssh-checkout'\n"
          "mv /home/tau-fedimint/.config/isolate/isolate.yaml.saved "
          "/home/tau-fedimint/.config/isolate/isolate.yaml\n"
          "rm /home/tau-fedimint/fedimint/root-owned-ssh-config "
          "/home/tau-fedimint/fedimint/negative-ssh-config"
      )

      # Exercise the published isolate/broker import-context protocol with the
      # generated production handler. Remove unrelated required binds so this
      # source-only VM can run without the live SSH agent.
      machine.succeed(
          "jq '"
          ".profiles[\"fedimint-bot\"].bind |= "
          "map(select(.path == \"/home/tau-fedimint/fedimint\" "
          "or .path == \"/tmp/public\"))"
          "' /home/tau-fedimint/.config/isolate/isolate.yaml "
          ">/home/tau-fedimint/.config/isolate/isolate.yaml.new\n"
          "mv /home/tau-fedimint/.config/isolate/isolate.yaml.new "
          "/home/tau-fedimint/.config/isolate/isolate.yaml\n"
          "chown tau-fedimint:tau-fedimint "
          "/home/tau-fedimint/.config/isolate/isolate.yaml\n"
          "install -d -m 0700 -o tau-fedimint -g tau-fedimint "
          "/home/tau-fedimint/.runtime "
          "/home/tau-fedimint/fedimint/fedimint/reviews/deep\n"
          "runuser -u tau-fedimint -- sh -euc '"
          "printf nested >"
          "/home/tau-fedimint/fedimint/fedimint/reviews/deep/review.md; "
          "printf shared >\"$(mktemp /tmp/public/review-import-XXXXXX)\"; "
          "printf outside >/home/tau-fedimint/outside.md; "
          "ln -s review.md "
          "/home/tau-fedimint/fedimint/fedimint/reviews/deep/linked.md; "
          "printf hardlink >"
          "/home/tau-fedimint/fedimint/fedimint/reviews/deep/hard-source.md; "
          "ln /home/tau-fedimint/fedimint/fedimint/reviews/deep/hard-source.md "
          "/home/tau-fedimint/fedimint/fedimint/reviews/deep/hardlink.md; "
          "mkfifo /home/tau-fedimint/fedimint/fedimint/reviews/deep/fifo.md'"
      )
      shared_body = machine.succeed(
          "find /tmp/public -maxdepth 1 -name 'review-import-*' -print -quit"
      ).strip()
      import_base = (
          "runuser -u tau-fedimint -- env HOME=/home/tau-fedimint "
          "XDG_RUNTIME_DIR=/home/tau-fedimint/.runtime "
          "isolate -c /home/tau-fedimint/fedimint "
          "exec --profile fedimint-bot -- ${pkgs.runtimeShell} -c '"
          "cd /home/tau-fedimint/fedimint/fedimint/reviews/deep && "
          "gh pr review 1 -R fedimint/fedimint --comment --body-file \"$1\""
          "' sh "
      )
      for name, body in [
          ("nested-relative", "review.md"),
          ("shared-absolute", shared_body),
      ]:
          status, output = machine.execute(import_base + body + " 2>&1")
          assert status == 125, (name, status, output)
          assert "open GitHub token secret: No such file or directory" in output
      for name, body in [
          ("outside-absolute", "/home/tau-fedimint/outside.md"),
          ("symlink", "linked.md"),
          ("hardlink", "hardlink.md"),
          ("fifo", "fifo.md"),
          ("cross-root-parent", "../../../../../../tmp/public/" + shared_body.rsplit("/", 1)[1]),
      ]:
          status, output = machine.execute(import_base + body + " 2>&1")
          assert status == 126, (name, status, output)
          assert "could not securely import text file" in output
          assert "open GitHub token secret" not in output

      machine.succeed(
          "cat >/home/tau-fedimint/.config/isolate/isolate.yaml <<'EOF'\n"
          '{"version":1,"profiles":{"tool-test":{"pid":{"mode":"private"},'
          '"bind_repo_root":true,"bind":[{"path":"/tmp/public","rw":true,'
          '"required":true,"kind":"dir"}],"setenv":{"HOME":"/home/tau-fedimint",'
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
           "for tool in rg jq python3 gpg; do command -v \"$tool\"; done; "
           "nix develop --offline --no-write-lock-file .#default "
           "--command bash -euc \""
           "command -v rg && command -v jq && command -v python3 && command -v gpg && "
           "rg --version && jq --version && python3 --version && gpg --version && just --version\"; "
          "test \"$(sha256sum flake.lock)\" = \"$lock_before\"; "
          "artifact=$(mktemp /tmp/public/isolate-artifact-XXXXXX); "
          "printf shared >\"$artifact\"; "
          "test \"$(cat \"$artifact\")\" = shared; "
          "! ls /tmp/public >/dev/null 2>&1; "
          "rm \"$artifact\"'"
      )
    '';
  };
in
assert failedBotAssertions defaultDisabled == [ ];
assert failedBotAssertions disabled == [ ];
assert failedBotAssertions enabled == [ ];
assert failedBotAssertions discordEnabled == [ ];
assert builtins.length (failedBotAssertions discordMissing) == 5;
assert builtins.length (failedBotAssertions discordReusedSecret) == 1;
assert builtins.length (failedBotAssertions reusedToken) == 1;
pkgs.linkFarm "tau-fedimint-bot-checks" [
  {
    name = "weekly-summary";
    path = weeklyCheck;
  }
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
