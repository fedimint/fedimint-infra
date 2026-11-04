# Fedimint Tau GitHub password backup

`secrets/tau-fedimint-github-password.age` is offline recovery material for the
`fedimint-tau` GitHub account, not a service credential.
[`secrets.nix`](../secrets.nix) encrypts it only to administrator recipients,
not host keys.

An administrator with the exact password and a recipient's private identity
can create or rotate the backup:

```console
just agenix-edit secrets/tau-fedimint-github-password.age "$HOME/.ssh/id_ed25519.agenix"
```

Enter only the password in a trusted local editor without plaintext backups or
external buffer sharing, then commit the ciphertext. Keep plaintext out of command
arguments, environment variables, logs, and shared artifacts. Without the password,
leave the file absent; do not create placeholder ciphertext.
