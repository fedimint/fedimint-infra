{ pkgs }:

let
  # agent-browser 0.27 automatically disables Chromium's sandbox in CI and
  # containers. Never silently accept that fallback in the bot environment.
  # This is agent-browser's first Linux auto-discovery name. Keep the alias
  # private to its PATH: setting AGENT_BROWSER_EXECUTABLE_PATH makes v0.27
  # launch a browser even for `close`, preventing cleanup after a launch error.
  chromium = pkgs.writeShellScriptBin "google-chrome" ''
    for arg in "$@"; do
      case "$arg" in
        --no-sandbox|--no-sandbox=*|--disable-setuid-sandbox|--disable-setuid-sandbox=*|--disable-namespace-sandbox|--disable-namespace-sandbox=*|--disable-seccomp-filter-sandbox|--disable-seccomp-filter-sandbox=*)
          echo "agent-browser: refusing to disable Chromium's sandbox" >&2
          exit 1
          ;;
      esac
    done
    exec ${pkgs.chromium}/bin/chromium "$@"
  '';
in
pkgs.writeShellApplication {
  name = "agent-browser";
  runtimeInputs = [
    chromium
    pkgs.coreutils
    pkgs.which
  ];
  text = ''
    # This subtree is writable inside the existing isolate profile. Do not
    # expose the rest of the user's runtime directory or a host browser profile.
    export AGENT_BROWSER_SOCKET_DIR="''${XDG_RUNTIME_DIR:?}/tau/agent-browser"
    (umask 077; mkdir -p "$AGENT_BROWSER_SOCKET_DIR")
    exec ${pkgs.agent-browser}/bin/agent-browser "$@"
  '';
}
