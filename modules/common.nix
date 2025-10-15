{ pkgs, ... }:

{
  services.sysstat = {
    enable = true;
    collect-frequency = "*:00/1";
  };

  services.automatic-timezoned.enable = false;
  time.timeZone = "UTC";

  environment.systemPackages = [
    pkgs.sysstat
  ];
}
