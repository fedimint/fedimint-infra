# Exposes basic host metrics (CPU, memory, disk IO, network, filesystems,
# load, pressure) for the Prometheus server in ./server.nix.
{ ... }:
let
  # runner-04 runs Prometheus; it is the only remote host allowed to scrape.
  prometheusServerIPv4 = "49.12.171.249";
  port = 9100;
in
{
  services.prometheus.exporters.node = {
    enable = true;
    inherit port;
    # Not `openFirewall`: that would publish host metrics to the internet.
    openFirewall = false;
  };

  # Appended before the final refuse rule; the chain is rebuilt on every
  # firewall reload, so no matching stop command is needed.
  networking.firewall.extraCommands = ''
    iptables -w -A nixos-fw -p tcp -s ${prometheusServerIPv4} --dport ${toString port} -j nixos-fw-accept
  '';
}
