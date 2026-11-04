# CI runner automation SSH access

[`flake.nix`](../flake.nix) authorizes the dedicated Fedimint automation key for
runner root accounts, alongside administrator keys. It does not grant access to
the unprivileged bot account or non-runner hosts.

An administrator with existing root access must activate each runner's
configuration with `just apply-runner RUNNER` from the reviewed checkout before
automation can use that key. The new identity cannot bootstrap its own access.
