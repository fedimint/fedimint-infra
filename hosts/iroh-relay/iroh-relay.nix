{ pkgs, hostName, ... }:
let
  domain = "${hostName}.dev.fedimint.org";

  iroh = import ../../modules/iroh-package.nix { inherit pkgs; };

  # https://github.com/n0-computer/iroh/blob/d4de591cb54be888e587320e6fb705648036ab38/iroh-relay/src/main.rs#L112
  relayConfig = pkgs.writeText "relay.toml" ''
    enable_relay = true

    [tls]
    hostname = "${domain}"
    cert_mode = "LetsEncrypt"
    contact = "contact@fedimint.org"

    enable_quic_addr_discovery = true
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
    allowedTCPPorts = [ 80 443 ];
    allowedUDPPorts = [ 3478 7842 ];
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
}
