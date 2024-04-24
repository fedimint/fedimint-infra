{ lib, pkgs, inputs, ... }:

let
  runnersNames = [
    "runner-01-aa"
    "runner-01-bb"
    "runner-01-cc"
    "runner-01-dd"
    "runner-01-ee"
    "runner-01-ff"
  ];
in
{

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
  # ideally, we would just want one user, but due to
  # https://github.com/btcsuite/btcd/pull/2177
  # we need to tie each worker and it's home to it's workdir 1:1
  users.users = lib.listToAttrs (map
    (name: {
      inherit name;
      value = {
        # behaves as normal user, needs a shell and home
        isNormalUser = true;
        group = "github-runner";
        home = "/var/lib/github-runner/${name}/";
        extraGroups = [ "docker" ];
      };
    })
    runnersNames);

  virtualisation.docker.enable = true;

  services.github-runners = lib.listToAttrs (map
    (name: {
      inherit name;
      value = {
        enable = true;
        inherit name;
        url = "https://github.com/fedimint";
        tokenFile = "/run/secrets/github-runner/token";
        user = name;
        serviceOverrides = {
          # we set home to the work dir, so mounting it RO messes things up
          ProtectHome = false;
          # To access /var/run/docker.sock we need to be part of docker group,
          # but it doesn't seem to work when it's mapped as `nobody` due to `PrivateUsers=true`
          PrivateUsers = false;
        };
        extraPackages = [
          pkgs.cachix
          pkgs.gawk
          pkgs.docker
        ];
      };
    })
    runnersNames);

}
