# recurringdv2

`recurringdv2-01` runs the stateless lnv2 LNURL proxy behind nginx.
[`hosts/recurringdv2/`](../hosts/recurringdv2) defines the service and host;
[`flake.nix`](../flake.nix) pins its package.

`recurringdv2.fedimint.org` is the public callback address.
Client apps embed `lnurl.fedimint.org`. Use
`recurringdv2-01.dev.fedimint.org` to check the host before public cutover.

## Moving hosts

There is no service data to migrate. Bootstrap using the
[host guide](hetzner-bootstrap.md), then compare real LNURL pay/invoice responses
through the host name before changing public DNS.

Lower TTLs in advance and keep the old deployment running until cached records
expire. Move both public names: certificates share an ACME account and their
orders depend on the alphabetically first name (`lnurl.fedimint.org`), so stale
DNS for it can block the others.

Once DNS resolves to the new host, start the
`acme-order-renew-NAME.service` units rather than waiting for the daily timer.
Until issuance, nginx serves self-signed placeholders; minimize that cutover gap.
