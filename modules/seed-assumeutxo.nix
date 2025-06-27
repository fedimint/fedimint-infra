{ pkgs, ... }:
let
  rqbitScript = ''
    set -e

    UTXO_FILE="/var/lib/rqbit-assumeutxo/utxo-840000.dat"
    EXPECTED_CHECKSUM="dc4bb43d58d6a25e91eae93eb052d72e3318bd98ec62a5d0c11817cefbba177b"
    MAGNET_URL="magnet:?xt=urn:btih:596c26cc709e213fdfec997183ff67067241440c&dn=utxo-840000.dat&tr=udp%3A%2F%2Ftracker.bitcoin.sprovoost.nl%3A6969"

    cd /var/lib/rqbit-assumeutxo

    if [[ -f "$UTXO_FILE" ]]; then
      CURRENT_CHECKSUM=$(sha256sum "$UTXO_FILE" | cut -d' ' -f1)
      if [[ "$CURRENT_CHECKSUM" == "$EXPECTED_CHECKSUM" ]]; then
        echo "File exists with correct checksum, sharing..."
        exec ${pkgs.rqbit}/bin/rqbit share utxo-840000.dat
      else
        echo "File exists but checksum is incorrect, removing and downloading..."
        rm -f "$UTXO_FILE"
      fi
    fi

    if [[ ! -f "$UTXO_FILE" ]]; then
      echo "File does not exist, downloading..."
      ${pkgs.rqbit}/bin/rqbit download "$MAGNET_URL"
      
      if [[ -f "$UTXO_FILE" ]]; then
        CURRENT_CHECKSUM=$(sha256sum "$UTXO_FILE" | cut -d' ' -f1)
        if [[ "$CURRENT_CHECKSUM" == "$EXPECTED_CHECKSUM" ]]; then
          echo "Downloaded file has correct checksum, sharing..."
          exec ${pkgs.rqbit}/bin/rqbit share utxo-840000.dat
        else
          echo "Downloaded file has incorrect checksum!"
          exit 1
        fi
      else
        echo "Download failed!"
        exit 1
      fi
    fi
  '';
in
{
  systemd.services.rqbit-assumeutxo = {
    description = "Share utxo-840000.dat over BitTorrent";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "exec";
      ExecStart = pkgs.writeShellScript "rqbit-assumeutxo-script" rqbitScript;
      WorkingDirectory = "/var/lib/rqbit-assumeutxo";
      StateDirectory = "rqbit-assumeutxo";
      User = "rqbit-assumeutxo";
      Group = "rqbit-assumeutxo";
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };

  users.users.rqbit-assumeutxo = {
    isSystemUser = true;
    group = "rqbit-assumeutxo";
    home = "/var/lib/rqbit-assumeutxo";
    createHome = true;
  };

  users.groups.rqbit-assumeutxo = { };

}
