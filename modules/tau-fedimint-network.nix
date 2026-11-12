{
  config,
  lib,
  pkgs,
  ...
}:

# Port-collision isolation for bot children, not a hostile-code boundary.
let
  enabled = config.services.tau-fedimint-bot.enable;
  ip = "${pkgs.iproute2}/bin/ip";
  rules = [
    "-i veth-tau -s 10.203.0.2/32 -j ACCEPT"
    "-o veth-tau -d 10.203.0.2/32 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT"
    "-o veth-tau -j DROP"
  ];
in
{
  config = lib.mkIf enabled {
    assertions = [
      {
        assertion = config.networking.firewall.enable && !config.networking.nftables.enable;
        message = "The bot network currently requires the iptables firewall backend.";
      }
    ];
    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
    networking.dhcpcd.denyInterfaces = [ "veth-tau" ];

    # Keep rules with the firewall, not the namespace service: firewall reloads
    # must restore them. Explicit ACCEPTs also survive Docker's FORWARD policy.
    networking.firewall.extraCommands = ''
      ${lib.concatMapStringsSep "\n" (rule: "iptables -w -A FORWARD ${rule}") rules}
      iptables -w -t nat -A POSTROUTING -s 10.203.0.2/32 ! -o veth-tau -j MASQUERADE
    '';
    networking.firewall.extraStopCommands = ''
      ${lib.concatMapStringsSep "\n" (rule: "iptables -w -D FORWARD ${rule} 2>/dev/null || true") rules}
      iptables -w -t nat -D POSTROUTING -s 10.203.0.2/32 ! -o veth-tau -j MASQUERADE 2>/dev/null || true
    '';
    networking.firewall.interfaces.veth-tau = {
      allowedUDPPorts = [ 53 ];
      allowedTCPPorts = [ 53 ];
    };

    # Forward through the host's normal resolver, including DHCP updates. The
    # loopback stub is not reachable from the bot's network namespace.
    services.resolved.enable = true;
    services.resolved.settings.Resolve.DNSStubListenerExtra = [ "10.203.0.1" ];
    environment.etc."netns/tau-fedimint/resolv.conf".text = ''
      nameserver 10.203.0.1
    '';

    systemd.services.tau-fedimint-network = {
      description = "Outbound IPv4 network namespace for the Fedimint bot";
      wantedBy = [ "multi-user.target" ];
      before = [ "tau-fedimint-bot.service" ];
      after = [
        "network-pre.target"
        "firewall.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStopPost = pkgs.writeShellScript "tau-fedimint-network-stop" ''
          ${ip} netns del tau-fedimint 2>/dev/null || true
          ${ip} link del veth-tau 2>/dev/null || true
        '';
      };
      script = ''
        ${ip} netns add tau-fedimint
        ${ip} link add veth-tau type veth peer name eth0 netns tau-fedimint
        ${ip} addr add 10.203.0.1/30 dev veth-tau
        ${ip} link set veth-tau up
        ${ip} -n tau-fedimint addr add 10.203.0.2/30 dev eth0
        ${ip} -n tau-fedimint link set lo up
        ${ip} -n tau-fedimint link set eth0 up
        ${ip} -n tau-fedimint route add default via 10.203.0.1
      '';
    };
  };
}
