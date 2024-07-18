{ lib, pkgs, ... }:
let
  timerName = "cleanup-tmp";
in
{
  systemd.services.${timerName} =
    let
      script = pkgs.writeShellScript "cleanup-github-runner-tmp" ''
        # tmp stuff  created by the github-runner user
        ${pkgs.findutils}/bin/find /tmp/ -mindepth 1 -maxdepth 1 -user github-runner -mmin +60 -print0 | xargs -n 1 -0 rm -rf
        # tmp stuff created by the nixbldX users
        ${pkgs.findutils}/bin/find /tmp/ -mindepth 1 -maxdepth 1 -group nixbld -mmin +60 -print0 | xargs -n 1 -0 rm -rf
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
