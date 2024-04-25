{ modulesPath, lib, pkgs, inputs, adminKeys, runnerName, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ./github-runner.nix
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
    pkgs.btop
    pkgs.htop
    pkgs.psmisc
    inputs.agenix.packages."${pkgs.system}".default
  ];

  system.stateVersion = "23.11";

  networking.enableIPv6 = true;

  users.users.root.openssh.authorizedKeys.keys = adminKeys;


  networking = {
    hostName = runnerName;
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

    gc = {
      automatic = true;
      persistent = true;
      dates = "monthly";
      options = "--delete-older-than 30d";
    };
  };
  services.journald.extraConfig = "SystemMaxUse=1G";
}
