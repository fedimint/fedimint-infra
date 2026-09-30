# CI runner automation SSH access

The dedicated Fedimint automation public key is authorized for `root` on the
configured CI runners: `runner-01`, `runner-02`, `runner-04`, and
`runner-arm-01`. It is added alongside the shared administrator keys only in
the runner configuration; it does not authorize the unprivileged `tau-fedimint`
account or non-runner hosts.

The key is SHA256:8jVZ5eJVh1aHisetDzl1o3g+BB26PpQ1QEn5cRRBnJo. This
configuration does not grant access until activated on each runner. In
particular, the automation identity cannot bootstrap `runner-02`, `runner-04`,
or `runner-arm-01` using that same key. An administrator with existing root
access must deploy the reviewed configuration to each host first, for example:

```sh
just apply-runner 02
just apply-runner 04
just apply-runner arm-01
```

Run these from the reviewed checkout with an authorized administrator SSH
identity. Confirm activation and key authentication on each host before
considering automation access live.
