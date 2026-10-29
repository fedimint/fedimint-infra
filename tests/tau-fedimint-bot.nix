{
  system,
  nixpkgs,
  agenix,
  module,
  tauPackage,
  isolatePackage,
  ghBrokerPackage,
  githubNotificationsPackage,
  skillsSource,
  fedimintSkillsSource,
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
  sshKey = builtins.toFile "ssh-private-key.age" "test-only";
  disabled = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      agenix.nixosModules.default
      module
      {
        system.stateVersion = "26.05";
        services.tau-fedimint-bot = {
          enable = true;
          inherit
            tauPackage
            ghBrokerPackage
            skillsSource
            fedimintSkillsSource
            ;
          isolatePackage = dummyIsolatePackage;
          clankPackage = dummyPackage "clank";
          githubTokenAgeFile = actionToken;
          sshPrivateKeyAgeFile = sshKey;
          sshAuthorizedKeys = [ "ssh-ed25519 test-only" ];
        };
      }
    ];
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
  disabledStart = disabled.config.systemd.user.services.tau-fedimint-bot.serviceConfig.ExecStart;
  notificationsEnabled = disabled.extendModules {
    modules = [
      {
        services.tau-fedimint-bot.githubNotifications = {
          enable = true;
          package = githubNotificationsPackage;
          tokenAgeFile = builtins.toFile "notification-token.age" "test-only";
          identityKeyAgeFile = builtins.toFile "notification-identity.age" "test-only";
        };
      }
    ];
  };
  notificationsStart =
    notificationsEnabled.config.systemd.user.services.tau-fedimint-bot.serviceConfig.ExecStart;
  notifierStartupCheck =
    pkgs.runCommand "tau-github-startup-check"
      {
        nativeBuildInputs = [
          pkgs.gnugrep
          (pkgs.python3.withPackages (python: [ python.cbor2 ]))
        ];
      }
      ''
        harness=$(grep -Eo '/nix/store/[^ ]+-tau-fedimint-harness.yaml' ${notificationsStart})
        python3 ${./tau-github-startup.py} \
          ${githubNotificationsPackage}/bin/tau-ext-github "$harness"
        touch "$out"
      '';
  githubRequesterPackage = lib.findFirst (
    package: lib.getName package == "fedimint-github-requester"
  ) (throw "fedimint-github-requester package missing") disabled.config.environment.systemPackages;
  direnvDpcPackage = lib.findFirst (
    package: lib.getName package == "direnv-dpc"
  ) (throw "direnv-dpc package missing") disabled.config.environment.systemPackages;
  tauSandboxPackage =
    lib.findFirst (package: lib.getName package == "tau-fedimint-sandbox")
      (throw "tau-fedimint-sandbox package missing from the Tau bot user profile")
      disabled.config.users.users.tau-fedimint.packages;
  configCheck =
    pkgs.runCommand "tau-fedimint-bot-config-check"
      {
        nativeBuildInputs = [
          pkgs.coreutils
          pkgs.git
          pkgs.gnugrep
        ];
      }
      ''
        set -euo pipefail

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
  tmpfilesCheck = pkgs.testers.runNixOSTest {
    name = "tau-fedimint-bot-tmpfiles";
    nodes.machine = {
      system.stateVersion = "26.05";
      virtualisation.memorySize = 4096;
      services.resolved.enable = true;
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
        pkgs.jq
        (pkgs.python3.withPackages (python: [
          python.pillow
        ]))
      ];
    };
    testScript = ''
      import shlex

      start_all()

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
          "runuser -u tau-fedimint -- sh -euc '"
          "artifact=$(mktemp /tmp/public/host-artifact-XXXXXX); "
          "printf shared >\"$artifact\"; "
          "test \"$(cat \"$artifact\")\" = shared; "
          "rm \"$artifact\"'"
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
      # Team membership belongs to the notifier, not the agent shell. Even the
      # configured team must remain inaccessible through the general gh broker.
      status, output = machine.execute(
          "runuser -u tau-fedimint -- env HOME=/home/tau-fedimint "
          "XDG_RUNTIME_DIR=/home/tau-fedimint/.runtime "
          "isolate -c /home/tau-fedimint/fedimint "
          "exec --profile fedimint-bot -- ${pkgs.runtimeShell} -c "
          "'cd /home/tau-fedimint/fedimint && "
          "gh api orgs/fedimint/teams/bot-access/members' 2>&1"
      )
      assert status == 126, (status, output)
      assert "gh invocation denied by isolate policy" in output, output
      assert "open GitHub token secret" not in output, output

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

    '';
  };
in
pkgs.linkFarm "tau-fedimint-bot-checks" [
  {
    name = "notifier-startup";
    path = notifierStartupCheck;
  }
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
]
