# Host bootstrap

Define the host in [`flake.nix`](../flake.nix) with system, hardware, and disk
configuration. Find existing layouts under [`hosts/`](../hosts) and
[`disk-config/`](../disk-config). With initial root SSH access, run
`just bootstrap HOST root@IP`; [`justfile`](../justfile) wraps nixos-anywhere.
Check the target and disk layout first: bootstrap wipes the configured disk.

If kexec fails with `kexec_file_load failed: Address not available` (seen on
Hetzner Cloud with Ubuntu 26.04), force the legacy syscall:

```console
nix run github:nix-community/nixos-anywhere -- --kexec-extra-flags "--kexec-syscall" --flake .#HOST root@IP
```
