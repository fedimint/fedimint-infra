{ pkgs, ... }:
let
  irohVersion = "v0.35.0";

  irohSrc = pkgs.fetchFromGitHub {
    owner = "n0-computer";
    repo = "iroh";
    tag = irohVersion;
    sha256 = "sha256-D/f/x8fv29O9rxJ/TuYc0myI/TDORkF88QwTkoZXXbg=";
  };

  iroh = pkgs.rustPlatform.buildRustPackage (
    {
      version = irohVersion;
      src = irohSrc;
      cargoLock = {
        lockFile = "${irohSrc}/Cargo.lock";
      };
      doCheck = false;
      meta = with pkgs.lib; {
        homepage = "https://github.com/n0-computer/iroh";
        license = licenses.mit;
        maintainers = with maintainers; [ ];
        description = "Iroh";
      };
      cargoBuildFlags = [ "--features" "server" ];
      pname = "iroh";
    }
  );

  # https://github.com/n0-computer/iroh/blob/d4de591cb54be888e587320e6fb705648036ab38/iroh-relay/src/main.rs#L112
  relayConfig = pkgs.writeText "relay.toml" ''
  '';

  # https://github.com/n0-computer/iroh/blob/d4de591cb54be888e587320e6fb705648036ab38/iroh-dns-server/src/config.rs#L29
  dnsConfig = pkgs.writeText "dns.toml" ''
    pkarr_put_rate_limit = "smart"

    [https]
    port = 443
    domains = ["irohdns.dev.fedimint.org"]
    cert_mode = "lets_encrypt"
    letsencrypt_prod = true
    letsencrypt_contact = "contact@fedimint.org"

    [dns]
    port = 53
    default_soa = "dns1.irohdns.dev.fedimint.org hostmaster.irohdns.dev.fedimint.org 0 10800 3600 604800 3600"
    default_ttl = 30
    origins = ["irohdns.dev.fedimint.org", "."]
    rr_a = "203.0.10.10"
    rr_ns = "ns1.irohdns.dev.fedimint.org."

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
    allowedUDPPorts = [ 53 3478 ];
  };

  systemd.services.iroh-relay =  {
      description = "Iroh Relay Server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${iroh}/bin/iroh-relay -c ${relayConfig}";
        Restart = "on-failure";
        User = "iroh";
        Group = "iroh";
        ProtectSystem = "full";
        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
        Environment = "RUST_LOG=iroh=debug";
      };
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
        ProtectSystem = "full";
        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
        Environment = "RUST_LOG=iroh=debug";
      };
    };
}
