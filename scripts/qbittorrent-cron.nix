{ pkgs, secrets, config }:
{
  scripts = {
    pause = pkgs.writeShellScriptBin "pause-torrents" ''
      set -euo pipefail

      # Pause all qBittorrent torrents, then resume those that were downloading.
      # Uses the `qbt` CLI and `jq` from Nixpkgs.

      QBT=${pkgs.qbittorrent-cli}/bin/qbt
      JQ=${pkgs.jq}/bin/jq
      URL="http://10.200.200.1:${toString config.services.qbittorrent.webuiPort}"
      QBT_USERNAME="${secrets.qbittorrent.user}"
      QBT_PASSWORD="${secrets.qbittorrent.password}"
      DRY_RUN="''${DRY_RUN:-0}"

      echo "Fetching downloading torrent from $URL..."

      DL_HASHES=$("$QBT" torrent list --format json --filter downloading --url "$URL" --username "$QBT_USERNAME" --password "$QBT_PASSWORD" 2>/dev/null | "$JQ" -r '.[].hash')

      echo "Pausing all torrents..."
      "$QBT" torrent pause all --url "$URL" --username "$QBT_USERNAME" --password "$QBT_PASSWORD"

      echo "Resuming previously downloading torrents..."
      while IFS= read -r h; do
        [[ -z "$h" ]] && continue
        if [[ "$DRY_RUN" -eq 1 ]]; then
          echo "DRY RUN: resume $h"
        else
          echo "Resuming $h..."
          "$QBT" torrent resume "$h" --url "$URL" --username "$QBT_USERNAME" --password "$QBT_PASSWORD" || true
        fi
      done <<< "$DL_HASHES"

      echo "Done."
    '';

    resume = pkgs.writeShellScriptBin "resume-torrents" ''
      set -euo pipefail

      QBT=${pkgs.qbittorrent-cli}/bin/qbt
      JQ=${pkgs.jq}/bin/jq
      URL="http://10.200.200.1:${toString config.services.qbittorrent.webuiPort}"
      QBT_USERNAME="${secrets.qbittorrent.user}"
      QBT_PASSWORD="${secrets.qbittorrent.password}"

      "$QBT" torrent resume all --url "$URL" --username "$QBT_USERNAME" --password "$QBT_PASSWORD"
    '';
  };
}
