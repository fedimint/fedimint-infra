{ modulesPath, lib, pkgs, inputs, adminKeys, hostName, ... }:

{
  imports = [
    ./github-runner.nix
    ./cleanup.nix
  ];
  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  services.openssh.enable = true;
  services.resolved.enable = true;

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


  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking = {
    inherit hostName;
    firewall = {
      allowPing = true;
    };
  };


  # General server stuff
  boot.tmp.cleanOnBoot = true;
  services.automatic-timezoned.enable = true;
  nix = {
    # 2.21 seems to break crane vendoring crates
    # package = pkgs.nixVersions.nix_2_21;

    extraOptions = ''
      experimental-features = nix-command flakes
    '';
    settings = {
      max-jobs = 2;
      auto-optimise-store = true;
      trusted-users = [ "root" "github-runner" ];
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
