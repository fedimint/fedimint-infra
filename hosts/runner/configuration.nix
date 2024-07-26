{ modulesPath, lib, pkgs, inputs, adminKeys, runnerName, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
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


  # attempting to workaround:
  # https://www.reddit.com/r/hetzner/comments/1e9l68o/ax102_servers_getting_shut_down_periodically_for/
  systemd.services."check-temp" = {
    description = "Check system temperature and prevent overheat";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "check-temp.sh" ''

        PATH="${pkgs.lm_sensors}/bin:${pkgs.gawk}/bin:${pkgs.cpufrequtils}/bin:$PATH"
        TEMP_THRESHOLD=80
        current_temp=$(sensors | grep 'Tctl:' | awk '{print $2}' | sed 's/+//;s/°C//' | cut -d'.' -f1)
        echo "Current temperature: ''${current_temp}°C"
        if [ "$current_temp" -ge "$TEMP_THRESHOLD" ]; then
            echo "Switching to powersave"
            cpufreq-set -g "powersave"
        else
            cpufreq-set -g "performance"
        fi
      '';
    };
  };

  systemd.timers."check-temp" = {
    description = "Run temperature check";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "1min";
    };
  };

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
    hostName = runnerName;
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
      experimental-features = nix-command flakes repl-flake
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
