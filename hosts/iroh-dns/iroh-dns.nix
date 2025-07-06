{ pkgs, hostName, ... }:
let
  domain = "${hostName}.dev.fedimint.org";

  iroh = import ../../modules/iroh-package.nix { inherit pkgs; };

  # https://github.com/n0-computer/iroh/blob/d4de591cb54be888e587320e6fb705648036ab38/iroh-dns-server/src/config.rs#L29
  dnsConfig = pkgs.writeText "dns.toml" ''
    pkarr_put_rate_limit = "smart"

    [http]
    port = 80
    bind_addr = "0.0.0.0"

    [https]
    port = 443
    domains = ["dns.${domain}", "${domain}"]
    cert_mode = "lets_encrypt"
    letsencrypt_prod = true
    letsencrypt_contact = "contact@fedimint.org"

    [dns]
    port = 53
    default_soa = "dns.${domain} hostmaster.${domain} 0 10800 3600 604800 3600"
    default_ttl = 30
    origins = ["dns.${domain}.", "."]
    rr_a = "157.180.123.56"
    rr_ns = "${domain}."

    [mainline]
    enabled = true
  '';
in
{
  environment.systemPackages = [
    iroh
  ];

  users.users.iroh = {
    isSystemUser = true;
    description = "Iroh service user";
    home = "/var/lib/iroh";
    createHome = true;
    group = "iroh";
  };
  users.groups.iroh = {};

  networking.firewall = {
    allowedTCPPorts = [ 53 80 443 ];
    allowedUDPPorts = [ 53 ];
  };

  systemd.services.iroh-dns-server = {
    description = "Iroh DNS Server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${iroh}/bin/iroh-dns-server -c ${dnsConfig}";
      Restart = "on-failure";
      User = "iroh";
      Group = "iroh";
      # ProtectSystem = "full";
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      Environment = "RUST_LOG=trace";

      # Additional permissions for network access
      PrivateNetwork = false;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
      IPAddressAllow = "any";
      RestrictNamespaces = false;
    };
  };
}
