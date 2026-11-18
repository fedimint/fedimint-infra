# Infrastructure automation SSH access

The dedicated Fedimint infrastructure operator key is authorized for `root`
alongside the shared administrator keys on these hosts:

- CI runners: `runner-01`, `runner-02`, `runner-04`, and `runner-arm-01`
- Test federation: `fedimintd-01` through `fedimintd-04`
- Iroh relays: `irohrelay-eu-01` and `irohrelay-us-01`
- Recurring payments proxy: `recurringdv2-01`

The key fingerprint is `SHA256:8jVZ5eJVh1aHisetDzl1o3g+BB26PpQ1QEn5cRRBnJo`.
This key is not the deployed Tau bot's key. It grants no access to the
`tau-fedimint` account or to the Iroh DNS hosts.

An administrator must activate the configuration on each new host using
an already-authorized identity. The operator key cannot bootstrap its own
access. Before connecting, verify the SSH host key through a trusted channel.
After deployment, verify public-key authentication.
