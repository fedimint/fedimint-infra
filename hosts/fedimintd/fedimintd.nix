{ pkgs, hostName, ... }:

let
  fmFqdn = "${hostName}.dev.fedimint.org";
  fmApiFqdn = fmFqdn;
  fmP2pFqdn = fmFqdn;
in
{
  users.groups = {
    bitcoind-signet-pass = { };
  };

  age.secrets = {
    bitcoind-signet-pass = {
      file = ../../secrets/bitcoind-signet-pass.age;
      path = "/run/secrets/bitcoind-signet-pass";
      group = "bitcoind-signet-pass";
      mode = "660";
    };
  };

  services.bitcoind.signet = {
    enable = true;
    prune = 550;
    dbCache = 2200;

    extraConfig = ''
      server=1
      signet=1
      # must match bitcoind-signet-pass.age
      rpcauth=bitcoin:6a894e7e43ceac9f7fe375fb4986c602$4a1a9b5d41e8b46b295b35b2a52d14d4280a40ed3d3ad12322e9656c501afb69
    '';
  };

  environment.systemPackages = [
    pkgs.fedimint.fedimint
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  systemd.services.fedimintd-signet.serviceConfig = {
    SupplementaryGroups = "bitcoind-signet-pass";
  };

  services.fedimintd."signet" = {
    enable = true;
    package = pkgs.fedimint.fedimint;

    environment = {
      "RUST_LOG" = "fm=debug,info";
      "RUST_BACKTRACE" = "1";
      "FM_BIND_METRICS_API" = "[::1]:8175";
      "FM_REL_NOTES_ACK" = "0_4_xyz";
    };

    api = {
      url = "wss://${fmApiFqdn}/ws/";
    };

    p2p = {
      url = "fedimint://${fmP2pFqdn}/";
    };

    bitcoin = {
      network = "signet";
      rpc = {
        url = "http://bitcoin@127.0.0.1:38332";
        secretFile = "/run/secrets/bitcoind-signet-pass";
      };
    };

    nginx = {
      enable = true;
      fqdn = fmApiFqdn;
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
  };
}
