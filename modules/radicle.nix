{ lib, pkgs, ... }: {

  # radicle-node 1.10.3 is marked insecure because private repository traffic
  # between nodes is neither encrypted nor authenticated. This node hosts only
  # public repositories, so that specific private-repository issue does not
  # apply here. Keep the exception scoped to the host using this module.
  nixpkgs.config.permittedInsecurePackages = [ "radicle-node-1.10.3" ];

  age.secrets = {
    radicle-seednode = {
      file = ../secrets/radicle-seednode.age;
      path = "/run/secrets/radicle/seednode";
      owner = "radicle";
      group = "radicle";
      mode = "660";
    };
  };

  services.radicle = {
    enable = true;
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMYKej/5RMfmhoyaOqHr/AZmhxrQGYBIm/U4dnfrLHSd";
    node.openFirewall = true;
    node.listenAddress = "[::0]";
    settings = {
      "web" = {
        "pinned" = {
          "repositories" = [
            "rad:z2eeB9LF8fDNJQaEcvAWxQmU7h2PG" # fedimint
            "rad:zPs9xPpx5ehT56shVzQ4BUnov9uE" # fedimint-infra
            "rad:z3j99jVF5NuLGuMj7LX9WZ8WvNaLo" # fedimint-ui
          ];
        };
      };
    };
    httpd.enable = true;
    httpd.nginx.serverName = "radicle.fedimint.org";
    httpd.nginx.enableACME = true;
    httpd.nginx.forceSSL = true;
  };

  systemd.services.radicle-node.serviceConfig = {
    ImportCredential = lib.mkForce [ ];
    LoadCredential = [ "dev.radicle.node.secret:/run/secrets/radicle/seednode" ];
  };

  environment.systemPackages = with pkgs; [
    perfit
  ];
}
