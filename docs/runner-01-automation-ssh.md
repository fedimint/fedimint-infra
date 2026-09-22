# runner-01 automation SSH access

The dedicated Fedimint automation public key is authorized for `root` only on
`runner-01`. It is not part of the shared administrator keys and does not
authorize the unprivileged `tau-fedimint` account or any other host.

The key is SHA256:8jVZ5eJVh1aHisetDzl1o3g+BB26PpQ1QEn5cRRBnJo. Before this
configuration has been deployed, the automation identity cannot access
`runner-01`. An existing administrator must use normal root SSH access to
deploy the configuration first; only after that deployment can the automation
identity authenticate.
