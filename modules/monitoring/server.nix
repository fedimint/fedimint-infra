# Prometheus + Grafana showing how busy the runners are over time.
# Every runner runs ./node-exporter.nix; this module is for one host only.
{ config, pkgs, ... }:
let
  domain = "grafana.dev.fedimint.org";
  grafanaPort = 3000;
  prometheusPort = 9090;
  scrapeInterval = "30s";
  datasourceUid = "prometheus";
  nodeExporterPort = config.services.prometheus.exporters.node.port;

  # Keep in sync with the runners in flake.nix.
  remoteRunners = [
    "runner-01"
    "runner-02"
    "runner-arm-01"
  ];

  nodeExporterFull = pkgs.fetchurl {
    name = "node-exporter-full.json";
    url = "https://raw.githubusercontent.com/rfmoz/grafana-dashboards/b07d8a90d8fadd112e9ac841b777ee863cda850b/prometheus/node-exporter-full.json";
    hash = "sha256-wueaXq0VU34OvidqKHjJXWKGyhq42yzX9p1LqMB53n4=";
  };
  runnersOverview = pkgs.writeText "runners-overview.json" (
    builtins.toJSON (import ./runners-overview.nix { inherit datasourceUid; })
  );
  # Grafana's dashboard provider expects a directory.
  dashboards = pkgs.linkFarm "grafana-dashboards" [
    {
      name = "runners-overview.json";
      path = runnersOverview;
    }
    {
      name = "node-exporter-full.json";
      path = nodeExporterFull;
    }
  ];

  grafanaSecret = file: {
    inherit file;
    owner = "grafana";
    group = "grafana";
    mode = "400";
  };
in
{
  age.secrets = {
    grafana-admin-password = grafanaSecret ../../secrets/grafana-admin-password.age;
    grafana-secret-key = grafanaSecret ../../secrets/grafana-secret-key.age;
  };

  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = prometheusPort;
    retentionTime = "90d";
    globalConfig.scrape_interval = scrapeInterval;
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString nodeExporterPort}" ];
            labels.instance = config.networking.hostName;
          }
        ]
        ++ map (host: {
          targets = [ "${host}.dev.fedimint.org:${toString nodeExporterPort}" ];
          labels.instance = host;
        }) remoteRunners;
      }
    ];
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = grafanaPort;
        inherit domain;
        root_url = "https://${domain}/";
      };
      security = {
        admin_user = "admin";
        # Only applied when Grafana creates its database; later changes go
        # through the UI or `grafana cli admin reset-admin-password`.
        admin_password = "$__file{${config.age.secrets.grafana-admin-password.path}}";
        secret_key = "$__file{${config.age.secrets.grafana-secret-key.path}}";
      };
      users.allow_sign_up = false;
      dashboards.default_home_dashboard_path = "${runnersOverview}";
      analytics.reporting_enabled = false;
    };
    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Prometheus";
          uid = datasourceUid;
          type = "prometheus";
          url = "http://127.0.0.1:${toString prometheusPort}";
          isDefault = true;
          # Lets $__rate_interval span enough scrapes.
          jsonData.timeInterval = scrapeInterval;
        }
      ];
      dashboards.settings.providers = [
        {
          name = "runners";
          options.path = dashboards;
        }
      ];
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "contact@fedimint.org";
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  services.nginx = {
    enable = true;
    virtualHosts.${domain} = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString grafanaPort}";
        proxyWebsockets = true;
      };
    };
  };
}
