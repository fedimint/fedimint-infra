{ pkgs, hostName, ... }:

let
  fmFqdn = "${hostName}.dev.fedimint.org";
  fmFqdnIroh = "${hostName}-iroh.dev.fedimint.org";
  bitcoindPasswordFile = "/run/secrets/bitcoind-signet-pass";
  bitcoindUrl = "http://127.0.0.1:38332";
  bitcoindUsername = "bitcoin";
  esploraUrl = "https://mempool.space/signet/api";
in
{
  users.groups = {
    bitcoind-signet-pass = { };
  };

  age.secrets = {
    bitcoind-signet-pass = {
      file = ../../secrets/bitcoind-signet-pass.age;
      path = bitcoindPasswordFile;
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

      # minimum memory usage settings, even on mainnet it will be slow but will work just fine
      maxmempool=5
      par=2
      rpcthreads=4
      maxconnections=32
    '';
  };

  systemd.services.bitcoind = {
    environment = {
      "MALLOC_ARENA_MAX" = "2";
    };
  };

  environment.systemPackages = [
    pkgs.fedimintd
    pkgs.fedimint-cli
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  systemd.services.fedimintd-signet.serviceConfig = {
    SupplementaryGroups = "bitcoind-signet-pass";
  };

  systemd.services.fedimintd-signet-iroh.serviceConfig = {
    SupplementaryGroups = "bitcoind-signet-pass";
  };

  services.fedimintd."signet" = {
    enable = true;
    package = pkgs.fedimintd;

    environment = {
      "RUST_LOG" = "fm=debug,info";
      "RUST_BACKTRACE" = "1";
      "FM_BIND_METRICS_API" = "[::1]:8175";
      "FM_BITCOIND_USERNAME" = bitcoindUsername;
      "FM_BITCOIND_URL" = bitcoindUrl;
      "FM_BITCOIND_URL_PASSWORD_FILE" = bitcoindPasswordFile;
      "FM_P2P_URL" = "fedimint://${fmFqdn}:8173/";
      "FM_API_URL" = "wss://${fmFqdn}/ws/";
    };

    api_ws = {
      url = "wss://${fmFqdn}/ws/";
    };

    p2p = {
      url = "fedimint://${fmFqdn}:8173/";
    };

    bitcoin = {
      network = "signet";
      bitcoindUrl = bitcoindUrl;
      esploraUrl = esploraUrl;
      bitcoindSecretFile = bitcoindPasswordFile;
    };

    nginx = {
      enable = true;
      fqdn = fmFqdn;
    };
  };

  services.fedimintd."signet-iroh" = {
    enable = true;
    package = pkgs.fedimintd;

    environment = {
      "RUST_LOG" = "fm=debug,info";
      "RUST_BACKTRACE" = "1";
      "FM_BIND_METRICS_API" = "[::1]:8275";
      "FM_ENABLE_IROH" = "true";
      "FM_IROH_DNS" = "https://dns.irohdns-eu-01.dev.fedimint.org";
      "FM_IROH_RELAY" = "https://irohrelay-eu-01.dev.fedimint.org";
      "FM_BITCOIND_USERNAME" = bitcoindUsername;
      "FM_BITCOIND_URL" = bitcoindUrl;
      "FM_BITCOIND_URL_PASSWORD_FILE" = bitcoindPasswordFile;
      "FM_P2P_URL" = "fedimint://${fmFqdnIroh}:8173/";
      "FM_API_URL" = "wss://${fmFqdnIroh}/ws/";
      "FM_BIND_P2P" = "0.0.0.0:8273";
      "FM_BIND_API" = "0.0.0.0:8274";
      "FM_BIND_UI" = "127.0.0.1:8275";
    };

    p2p = {
      port = 8273;
      url = "fedimint://${fmFqdnIroh}:8173/";
    };

    api_ws = {
      port = 8274;
      url = "wss://${fmFqdnIroh}/ws/";
    };

    api_iroh = {
      port = 8274;
    };

    ui = {
      port = 8275;
    };

    bitcoin = {
      network = "signet";
      bitcoindUrl = bitcoindUrl;
      esploraUrl = esploraUrl;
      bitcoindSecretFile = bitcoindPasswordFile;
    };

    nginx = {
      enable = true;
      fqdn = fmFqdnIroh;
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
