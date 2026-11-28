{ pkgs, ... }:

let
  nofileSoft = 8192;
  nofileHard = 524288;
  nofile = "${toString nofileSoft}:${toString nofileHard}";
in
{
  services.sysstat = {
    enable = true;
    collect-frequency = "*:00/1";
  };

  services.automatic-timezoned.enable = false;
  time.timeZone = "UTC";

  # Keep the inherited defaults aligned for services and login sessions.
  # See docs/open-file-limits.md for the select(2) caveat and rollout checks.
  systemd.settings.Manager.DefaultLimitNOFILE = nofile;
  systemd.user.extraConfig = ''
    DefaultLimitNOFILE=${nofile}
  '';
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "soft";
      item = "nofile";
      value = toString nofileSoft;
    }
    {
      domain = "*";
      type = "hard";
      item = "nofile";
      value = toString nofileHard;
    }
  ];

  environment.systemPackages = [
    pkgs.sysstat
  ];
}
