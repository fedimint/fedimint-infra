{ pkgs, inputs, hostName, ... }:
let
  hostFqdn = "${hostName}.dev.fedimint.org";
  # Public name the service is reached at. Also used as `FM_API_ADDRESS`, so
  # LNURL-pay callbacks handed out by this host point back at it.
  publicFqdn = "recurringdv2.fedimint.org";

  bindApi = "127.0.0.1:8176";

  recurringdv2 =
    inputs.fedimint-recurringdv2.packages.${pkgs.stdenv.hostPlatform.system}.fedimint-recurringdv2;

  vhost = {
    enableACME = true;
    forceSSL = true;
    locations."/".proxyPass = "http://${bindApi}";
  };
in
{
  imports = [
    ../../modules/common.nix
  ];

  environment.systemPackages = [
    recurringdv2
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  systemd.services.fedimint-recurringdv2 = {
    description = "Fedimint recurringdv2 LNURL proxy";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      FM_BIND_API = bindApi;
      FM_API_ADDRESS = "https://${publicFqdn}/";
      RUST_LOG = "info";
    };
    serviceConfig = {
      ExecStart = "${recurringdv2}/bin/fedimint-recurringdv2";
      Restart = "always";
      RestartSec = 5;

      # Stateless service, no data directory needed.
      DynamicUser = true;
      NoNewPrivileges = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      # AF_NETLINK is used by iroh's network monitor.
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK" ];
      LimitNOFILE = 65536;
    };
  };

  security.acme = {
    defaults.email = "contact@fedimint.org";
    acceptTerms = true;
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;

    virtualHosts = {
      ${hostFqdn} = vhost;
      # Until a public DNS record points at this host, ordering its
      # certificate fails and nginx serves a self-signed placeholder for it.
      ${publicFqdn} = vhost;
      # Hardcoded as the recurringd v2 URL in client apps (e.g. Fedi).
      "lnurl.fedimint.org" = vhost;
    };
  };
}
