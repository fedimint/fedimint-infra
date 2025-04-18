{ lib, pkgs, ... }: {
  # attempting to workaround:
  # https://www.reddit.com/r/hetzner/comments/1e9l68o/ax102_servers_getting_shut_down_periodically_for/
  # Only relevant for bare-metal AMD servers
  systemd.services."check-temp" = {
    description = "Check system temperature and prevent overheat";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "check-temp.sh" ''

        PATH="${pkgs.lm_sensors}/bin:${pkgs.gawk}/bin:${pkgs.cpufrequtils}/bin:$PATH"
        TEMP_THRESHOLD=80
        current_temp=$(sensors | grep 'Tctl:' | awk '{print $2}' | sed 's/+//;s/°C//' | cut -d'.' -f1)
        echo "Current temperature: ''${current_temp}°C"
        if [ "$current_temp" -ge "$TEMP_THRESHOLD" ]; then
            echo "Switching to powersave"
            cpufreq-set -g "powersave"
        else
            cpufreq-set -g "performance"
        fi
      '';
    };
  };

  systemd.timers."check-temp" = {
    description = "Run temperature check";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "1min";
    };
  };
}