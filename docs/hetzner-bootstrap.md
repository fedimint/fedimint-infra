
## Overview

To bootstrap a host you need:

* `configuration.nix` - system config, can be barebone, needs to enable network, ssh and set root ssh-key
* `hardware-configuration.nix` - easy for VPS, for hardware boxes see below
* `disk-config.nix` - copy&modify existing one, see docs for disko project


If you have these ready, you only need to  initial ssh access to the box : 

```
ssh-copy-id root@fedimint-runner-01
```

then run `just bootstrap <args>` and let it do its job. That should be it.

## Switching into NixOS Installer

In case you just need to switch to NixOS installer for some reason.

After `ssh-copy-id`, you can easily switch any Linux / rescue mode boot into NixOS installer via `kexec` method from https://github.com/nix-community/nixos-images#kexec-tarballs:

```
curl -L https://github.com/nix-community/nixos-images/releases/download/nixos-unstable/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz | tar -xzf- -C /root
/root/kexec/run
```

At this point you have the system booted with nixos installer image, so you can generate hardware config and/or use
installer, or bootstrap using nixos-anywhere.
