{ lib, pkgs, ... }:
let
  timerName = "cleanup-tmp";
in
{
  systemd.services.${timerName} =
    let
      script = pkgs.writeShellScript "cleanup-github-runner-tmp" ''
        # all files created by the github-runner user
        ${pkgs.findutils}/bin/find /tmp/ -mindepth 1 -type f -user github-runner -mmin +120 -delete
        ${pkgs.findutils}/bin/find /tmp/ -mindepth 1 -type d -user github-runner -mmin +120 -empty -delete
        # all files created by the nixbldX users (nixbld group)
        ${pkgs.findutils}/bin/find /tmp/ -mindepth 1 -type f -group nixbld -mmin +120 -delete
        ${pkgs.findutils}/bin/find /tmp/ -mindepth 1 -type d -group nixbld -mmin +120 -empty -delete
      '';
    in
    {
      description = "Clean up /tmp files not accessed in the last 24h";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = script;
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
