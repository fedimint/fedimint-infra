{ modulesPath, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
  ];
  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  services.openssh.enable = true;

  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.gitMinimal
    pkgs.helix
    pkgs.tmux
    inputs.agenix.packages."${pkgs.system}".default
    pkgs.cachix
  ];

  users.users.root.openssh.authorizedKeys.keys = [
    # dpc
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDRa93v8pzO+EXEH73odhh80VjkLVzPCaRw4K0sObdE9mbZqFB6k791Jm1cVQzHA+sCR4bnyOvA563ExLSGArw4IRxCZvZICSb8RI4QaIhCgf0NtwndKaBxnS2aWrJ/VKNmlZ4OsHMxrFtDRg0AHXBkj0H2O06bJ0+fiwiKdun1tqqi78qQPZkjaJoB227ipx3T0f9Oflj09iWVT3C0saaAiCtpa50ggjImom1FAwNF0gLhPGbSgUzsHzAndwexXWD5StAfWuePaapbQ0IIAY9ahlTKCXGSV0oS/IrBDjOfIaXoyzzgT4/xTz6dwie2g255mGTDn6k0CYkWX19H8xzT2TQ7e4ikNrXVdcRRRy4rd22MA75546RVD2mm36C0DnaUsnBUwymuQ02z33iTm8U7CZXQWpiKjwgqCtvs9zrsRx1YECHCw5ehUDt2nMw4ino42jthxV9bgQDQg/On7frBUXeKkd7L0UVfC71DW9AQQTvdHA2POpPhtoi7BznOeFMoVXxBMgJSgwGTH3ErY0zbvMLJNNROXby4rABmb7XTl5bav5DYD2lWzhcseN6a+/PgREyzllQxJqWQVQvA00JFuaNFLI7JeyIULUgyYuS5n/jEvmKKnzhwuGlHnIKF5UPViaF3WRiFSTop6taZNptBFWGBsG7eT8rTxb/FKtylVw== cardno:20_514_157"
  ];

  system.stateVersion = "23.11";

  networking.enableIPv6 = true;


  networking = {
    firewall = {
      allowPing = true;
    };
  };


  # General server stuff
  boot.tmp.cleanOnBoot = true;
  services.automatic-timezoned.enable = true;
  nix = {
    package = pkgs.nixVersions.nix_2_21;

    extraOptions = ''
      experimental-features = nix-command flakes repl-flake
    '';
    settings = {
      max-jobs = "auto";
      auto-optimise-store = true;
    };
    daemonIOSchedClass = "idle";
    daemonIOSchedPriority = 7;
    daemonCPUSchedPolicy = "idle";

    gc = {
      automatic = true;
      persistent = true;
      dates = "monthly";
      options = "--delete-older-than 30d";
    };
  };
  services.journald.extraConfig = "SystemMaxUse=1G";


  age.secrets = {
    github-runner-token = {
      file = ../../secrets/github-runner.age;
      path = "/run/secrets/github-runner/nixos.token";
      owner = "github-runner";
      group = "github-runner";
      mode = "600";
    };
  };

  users.groups.github-runner = { };
  users.users.github-runner = {
    # behaves as normal user, needs a shell and home
    isNormalUser = true;
    group = "github-runner";
  };

  services.github-runners = lib.listToAttrs (map
    (name: {
      inherit name;
      value = {
        enable = true;
        inherit name;
        url = "https://github.com/fedimint";
        tokenFile = "/run/secrets/github-runner/nixos.token";
        user = "github-runner";
      };
    }) [
    "runner-01-a"
    "runner-01-b"
    "runner-01-c"
    "runner-01-d"
    "runner-01-e"
    "runner-01-f"
    "runner-01-g"
    "runner-01-h"
  ]);
}
