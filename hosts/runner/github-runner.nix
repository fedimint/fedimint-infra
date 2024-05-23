{ lib, pkgs, inputs, runnerName, ... }:

let
  runnersNames = [
    "${runnerName}-aa"
    "${runnerName}-bb"
    "${runnerName}-cc"
  ];
in
{

  boot.tmp.useTmpfs = true;
  boot.tmp.cleanOnBoot = true;


  environment.systemPackages = map lib.lowPrio [
  ];

  age.secrets = {
    github-runner-token = {
      file = ../../secrets/github-runner.age;
      path = "/run/secrets/github-runner/token";
      # Note: this doesn't need to be readable to the runner user(s)
      # Seems like NixOS script will register with GH first, then
      # allow runner user to see only the post-registration creds,
      # which is much safer.
      owner = "root";
      group = "root";
      mode = "600";
    };
  };

  users.groups.github-runner = { };
  users.users.github-runner = {
    # behaves as normal user, needs a shell and home
    isNormalUser = true;
    group = "github-runner";
    home = "/home/github-runner";
    extraGroups = [ "docker" ];
  };

  virtualisation.docker.enable = true;

  services.github-runners = lib.listToAttrs (map
    (name: {
      inherit name;
      value = {
        enable = true;
        # this will shut down the whole service after every run,
        # notably making sure there is no ghosts processses
        ephemeral = true;
        replace = true;
        inherit name;
        url = "https://github.com/fedimint";
        tokenFile = "/run/secrets/github-runner/token";
        user = "github-runner";
        serviceOverrides = {
          # To access /var/run/docker.sock we need to be part of docker group,
          # but it doesn't seem to work when it's mapped as `nobody` due to `PrivateUsers=true`
          PrivateUsers = false;

          # lncli just has to touch the real home and won't tolerate `HOME` envvar
          ProtectHome = false;


          # These are hard to wipe, break cachix, break `--keep-failed-build`, etc.
          PrivateTmp = false;
          ProtectSystem = "full"; # instead of "strict", to make /tmp actually usable

          # Share the same portalloc dir so workers don't suffer random port conflicts
          Environment = ''
            "FM_PORTALLOC_DATA_DIR=/home/github-runner/.cache/port-alloc"
          '';
        };
        extraPackages = [
          # Broken: https://github.com/cachix/cachix-action/issues/179
          # pkgs.cachix
          pkgs.gawk
          pkgs.docker
        ];
      };
    })
    runnersNames);

}
