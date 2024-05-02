{ config, lib, pkgs, ... }:
let
  timerName = "cleanup-tmp";
  serviceName = "${timerName}.service";
in {
  systemd.services.${serviceName} = {
    description = "Clean up /tmp files not accessed in the last 24h";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.findutils}/bin/find /tmp -type f -atime +1 -delete";
      User = "root";
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.timers.${timerName} = {
    description = "Timer for cleaning up /tmp files";
    partOf = [ serviceName ];
    wantedBy = [ "timers.target" "multi-user.target" ];
    timerConfig = {
      OnCalendar = "daily";
    };
  };
}