{ pkgs, ... }: {

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
    privateKeyFile = "/run/secrets/radicle/seednode";
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMYKej/5RMfmhoyaOqHr/AZmhxrQGYBIm/U4dnfrLHSd dpc@ren";
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


  environment.systemPackages = with pkgs; [
    perfit
  ];
}
