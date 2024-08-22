{ lib, pkgs, ... }:
let
  cleanupTmp = "cleanup-tmp";
  gcNix = "gc-nix";
in
{
  systemd.services.${cleanupTmp} =
    let
      script = pkgs.writeShellScript "cleanup-github-runner-tmp" ''
        # tmp stuff  created by the github-runner user
        ${pkgs.findutils}/bin/find /tmp/ -mindepth 1 -maxdepth 1 -user github-runner -mmin +60 -print0 | xargs -n 1 -0 rm -rf
        # tmp stuff created by the nixbldX users
        ${pkgs.findutils}/bin/find /tmp/ -mindepth 1 -maxdepth 1 -group nixbld -mmin +60 -print0 | xargs -n 1 -0 rm -rf
      '';
    in
    {
      description = "Clean up /tmp files not accessed in the last 1h";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = script;
        User = "root";
      };
    };

  systemd.timers.${cleanupTmp} = {
    description = "Timer for cleaning up /tmp files";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
    };
  };

  systemd.services.${gcNix} =
    let
      script = pkgs.writeShellScript "gc-nix-store" ''
        ${pkgs.nix}/bin/nix-collect-garbage -d --delete-older-than 7d
      '';
    in
    {
      description = "GC the /nix store";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = script;
        User = "root";
      };
    };

  systemd.timers.${gcNix} = {
    description = "Timer for gc the /nix store";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
    };
  };
}
