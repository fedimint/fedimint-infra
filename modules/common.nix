{ pkgs, ... }:

{
  services.sysstat = {
    enable = true;
    collect-frequency = "*:00/1";
  };

  environment.systemPackages = [
    pkgs.sysstat
  ];
}
