{ pkgs, ... }: {

  age.secrets = {
    perfitd = {
      file = ../secrets/perfitd.age;
      path = "/run/secrets/perfitd/token";
      owner = "perfitd-fedimint";
      group = "perfitd-fedimint";
      mode = "600";
    };
  };

  environment.systemPackages = with pkgs; [
    perfit
  ];

  networking = {
    firewall = {
      allowPing = true;
      allowedTCPPorts = [ 80 443 ];
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "contact@fedimint.org";
  };

  services.perfitd."fedimint" = {
    enable = true;
    rootAccessTokenFile = "/run/secrets/perfitd/token";
  };

  services.nginx =
    let
      resolver = [ "8.8.8.8" ];
    in
    {
      enable = true;
      resolver.addresses = resolver;
      proxyResolveWhileRunning = true;
      recommendedProxySettings = true;
      recommendedOptimisation = true;
      recommendedTlsSettings = true;
      recommendedGzipSettings = true;
      recommendedBrotliSettings = true;
      proxyTimeout = "120s";
      eventsConfig = ''
        worker_connections   10000;
      '';
      appendConfig = ''
        worker_rlimit_nofile 100000;
      '';
      appendHttpConfig = ''
        server_names_hash_bucket_size 128;
        proxy_headers_hash_max_size 8192;
        proxy_headers_hash_bucket_size 128;
      '';

      virtualHosts = {
        "perfit.dev.fedimint.org" = {
          enableACME = true;
          forceSSL = true;
          locations."/" = {
            proxyPass = "http://[::1]:5050";
            extraConfig = ''
              proxy_pass_header Authorization;
            '';
          };
        };
      };
    };
}
