{ lib, pkgs, ... }:
let
  cleanupTmp = "cleanup-tmp";
  cleanupDocker = "cleanup-docker";
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
      OnCalendar = "*-*-* *:05:00";
      RandomizedDelaySec = "30min";
    };
  };

  systemd.services.${cleanupDocker} =
    let
      script = pkgs.writeShellScript "cleanup-docker" ''
        ${pkgs.docker_29}/bin/docker image prune -af --filter "until=48h"
      '';
    in
    {
      description = "Clean up old docker images";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = script;
        User = "root";
      };
    };

  systemd.timers.${cleanupDocker} = {
    description = "Timer for cleaning up /tmp files";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 02:17:00";
      RandomizedDelaySec = "3h";
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
      OnCalendar = "*-*-* 03:23:00";
      RandomizedDelaySec = "8h";
    };
  };
}
