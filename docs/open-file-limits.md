# Open-file limits

New PAM login sessions and services that the system or user systemd manager
starts default to 8192 soft and 524288 hard open file descriptors per process.
Explicit unit limits take precedence. `tau-fedimint-bot` starts with a soft
limit of 65536 and a hard limit of 524288.

On Linux, programs using `select(2)` cannot monitor descriptors numbered 1024
or higher (`FD_SETSIZE`). For services that need this compatibility, set
`LimitNOFILE=1024:524288` on the unit.

## Verify a staged rollout

Start with one managed host. After activation, open two fresh PAM login
sessions: one as a regular user and one as root. In each session, run
`ulimit -Sn` and `ulimit -Hn` and expect 8192 soft and 524288 hard.

Then check fresh transient units under the system and user managers:

```sh
sudo systemd-run --wait --pipe cat /proc/self/limits
systemd-run --user --wait --pipe cat /proc/self/limits
```

In both outputs, look for `Max open files` with 8192 soft and 524288 hard.
If a user manager is already running, including a lingering manager, you may
need to run `systemctl --user daemon-reload` before testing new user units.
Existing processes keep their limits.

Check representative services and their logs before proceeding to more hosts.
On a runner with the bot enabled, wait for an authorized bot restart before
checking `/proc/<MainPID>/limits` for a soft limit of 65536 and a hard limit of
524288.
