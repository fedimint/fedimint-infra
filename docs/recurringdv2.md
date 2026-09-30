# recurringdv2

`recurringdv2-01` (65.109.14.99) runs `fedimint-recurringdv2`, the stateless
LNURL proxy for lnv2, behind nginx. It serves three names:

* `recurringdv2-01.dev.fedimint.org` - host name, used for SSH and for
  testing the service before it takes public traffic.
* `recurringdv2.fedimint.org` - public name. `FM_API_ADDRESS` is set to it, so
  LNURL-pay callbacks handed out by this host point at it.
* `lnurl.fedimint.org` - the recurringd v2 URL hardcoded in client apps
  (e.g. Fedi), so LNURLs in the wild point at this name.

All certificates share one ACME account, and NixOS orders them behind the
alphabetically first one (`lnurl.fedimint.org`). If that name does not resolve
to this host, orders and renewals of the other certificates fail with a
dependency error too.

The service keeps no state, so moving it between hosts only means moving DNS.

## Bootstrap

1. Add DNS: `recurringdv2-01.dev.fedimint.org A 65.109.14.99`.
2. `ssh-copy-id root@65.109.14.99`
3. `just bootstrap recurringdv2-01 root@65.109.14.99`

This assumes a Hetzner Cloud x86_64 VPS with its disk at `/dev/sda`
(`disk-config/hetzner-vps.nix`); check with `lsblk` and `uname -m` first,
the bootstrap wipes that disk.

Until `recurringdv2.fedimint.org` points at the host, ordering its certificate
fails (`acme-order-renew-recurringdv2.fedimint.org.service`) and nginx serves a
self-signed placeholder for that name. This is expected.

## Verify before cutover

```
curl https://recurringdv2-01.dev.fedimint.org/
# recurringdv2 is up and running at https://recurringdv2.fedimint.org/
```

Compare `/pay/<payload>` and `/invoice/<payload>?amount=<msat>` responses for a
real LNURL payload against the current deployment; only the callback host
should differ.

## Cutover

1. Lower the TTL of `recurringdv2.fedimint.org` and wait out the old TTL.
2. Replace the CNAME with `A 65.109.14.99`.
3. Once public resolvers return the new address, order the certificate
   right away instead of waiting for the daily timer:

   ```
   ssh root@recurringdv2-01.dev.fedimint.org \
     systemctl start acme-order-renew-recurringdv2.fedimint.org.service
   curl https://recurringdv2.fedimint.org/
   ```

Until the certificate is issued, clients that already see the new address get
a TLS error, so do step 3 immediately after step 2. Keep the old deployment
running until the old TTL has expired.
