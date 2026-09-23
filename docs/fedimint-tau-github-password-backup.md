# Fedimint Tau GitHub password backup

The `fedimint-tau` GitHub account password has an offline backup policy at
`secrets/tau-fedimint-github-password.age`. This is recovery material only. No
host, NixOS `age.secrets` entry, service, or bot receives the decrypted
password.

The policy encrypts only to the administrator recipients named `users` in
`secrets.nix`. It deliberately excludes every host key.

## Populate or rotate the backup

The encrypted file is not a password placeholder. If it does not exist, an
administrator who has the exact account password and a private identity for one
of the configured administrator recipients must create it locally:

```console
just agenix-edit secrets/tau-fedimint-github-password.age "$HOME/.ssh/id_ed25519.agenix"
```

Enter only the exact password in the editor opened by agenix, then save and
exit. Use a trusted local editor configured not to retain plaintext swap or
backup files and not to send buffer contents to an external service. Commit the
resulting `.age` ciphertext separately. Never pass the password through command
arguments, environment variables, shell history, chat, tickets, logs, or
shared artifacts.

Do not create placeholder ciphertext. If the password is unavailable, leave
the encrypted file absent until an administrator can supply the real value
through the local editor.
