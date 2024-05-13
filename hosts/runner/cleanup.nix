{ config, lib, pkgs, ... }:
let
  timerName = "cleanup-tmp";
in
{
  systemd.services.${timerName} = {
    description = "Clean up /tmp files not accessed in the last 24h";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.findutils}/bin/find /tmp -type f -atime +1 -delete";
      User = "root";
    };
  };

  systemd.timers.${timerName } = {
    description = "Timer for cleaning up /tmp files";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
    };
  };
}
