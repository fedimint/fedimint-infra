{ pkgs, ... }:

let
  # Stay on the pinned kernel's stable branch without updating unrelated
  # userspace. 7.2.10 first fixed CVE-2026-98432; use the complete stable update.
  # Remove this override once the nixpkgs pin supplies a suitable fixed kernel;
  # reassess the recipe and source together whenever that pin changes.
  version = "7.2.14";
  kernel = pkgs.linux_latest.override {
    argsOverride = {
      inherit version;
      modDirVersion = version;
      src = pkgs.fetchurl {
        url = "mirror://kernel/linux/kernel/v7.x/linux-${version}.tar.xz";
        hash = "sha256-uxuHHvlajeELP3t7rw4NdUq79iD4BLbK+GDyJqqXZH0=";
      };
    };
  };
in
{
  boot.kernelPackages = pkgs.linuxPackagesFor kernel;
}
