{ lib, pkgs, ... }:
{
  # Keep the locked Nixpkgs recipe and its module overrides; replace only
  # the stable nginx release until our Nixpkgs pin includes the security fix.
  nixpkgs.overlays = [
    (final: prev: {
      nginxStable =
        if lib.versionOlder (lib.getVersion prev.nginxStable) "1.30.7" then
          prev.nginxStable.overrideAttrs (_: {
            version = "1.30.7";
            nginxVersion = "1.30.7";
            src = final.fetchurl {
              url = "https://nginx.org/download/nginx-1.30.7.tar.gz";
              hash = "sha256-JWW1yDcFDpWPcPsPc8SOK8pFQq00n9NW9G+wxyYQvG4=";
            };
          })
        else
          prev.nginxStable;
    })
  ];

  # None of our declared workloads uses SCTP. Block modprobe on the running
  # kernel and enforce the same block in the kernel itself after a reboot.
  boot.blacklistedKernelModules = [
    "sctp"
    "sctp_diag"
  ];
  boot.extraModprobeConfig = ''
    install sctp ${pkgs.coreutils}/bin/false
    install sctp_diag ${pkgs.coreutils}/bin/false
  '';
  boot.kernelParams = [ "module_blacklist=sctp,sctp_diag" ];
}
