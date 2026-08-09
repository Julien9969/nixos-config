{ config, lib, pkgs, secrets, ... }:
let
  notify-discord = import ../../scripts/notify-discord.nix { inherit secrets pkgs; };
  cfg = config.services.myServices.restic-backup;
  config-backup-folder = "/media/DSK/mediaserver-data/config-backups/restic";
  data-backup-folder = "/media/DSK/mediaserver-data/data-backups/restic";
in
{
  options.services.myServices.restic-backup = {
    enable-config = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable restic backup config service";
    };
    enable-data = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable restic backup data service";
    };
  };

  config = {

    services.restic.backups."server-db" = lib.mkIf cfg.enable-config {
      initialize = true;
      user = "root";
      repository = config-backup-folder;
      passwordFile = config.sops.secrets.restic_passwd.path;
      # Backup PostgreSQL database (usefull for Paperless-ng restore)
      command = [
        "${pkgs.util-linux}/bin/runuser"
        "-u"
        "postgres"
        "--"
        "${pkgs.postgresql}/bin/pg_dumpall"
      ];

      # Give the stream a filename inside the Restic snapshot
      extraBackupArgs = [ "--stdin-filename" "postgres-dump.sql" ];

      timerConfig = {
        OnCalendar = "Sun,Wed,Fri *-*-* 03:00:00";
        Persistent = true;
      };

      pruneOpts = [
        "--keep-last 10"
      ];

      # TODO: Add a cleanup command to notify Discord when the backup is complete
    };

    services.restic.backups."server-config" = lib.mkIf cfg.enable-config {
      initialize = true;
      user = "root";
      repository = config-backup-folder;
      passwordFile = config.sops.secrets.restic_passwd.path;
      paths = [
        "/home/trizotto/compose-files"
        "/var/lib/my-config"
        "${config.users.users.trizotto.home}/.config/sops/age/keys.txt"
        "${config.users.users.trizotto.home}/.ssh"
        "/etc/nixos"
      ];
      exclude = [
        "**/.cache/**"
        "**/cache/**"
        "**/logs/**"
        "**/node_modules/**"
        "**/MediaCover/**" # radarr, sonarr, etc
        "**.bak"
        "**/jellyfin/metadata/**"
        "**/jellyfin/temp/**"
        "**/jellyfin/data/subtitles/**"
        "**/jellyfin/data/introskipper/chromaprints/**"
        "**/jellyfin/data/attachments/**"
        "**/jellyfin/data/trickplay/**"
        "**/jellyfin/data/livetv/recordings/**"
        "**/MediaCover/**"
        "**/logs/**"
        "**/qBittorrent/cache/**"
        "/home/trizotto/cms/**"

        # Exclude Jellyfin plugins, but keep plugin configurations
        "**/jellyfin/plugins/**"
        "!**/jellyfin/plugins/configurations/**"

        "**/crafty/backups/**"
        "**/crafty/servers/**"
        "**/crafty/logs/**"
      ];

      timerConfig = {
        OnCalendar = "Sun,Wed,Fri *-*-* 03:05:00";
        Persistent = true;
      };
      
      extraOptions = [
        "--verbose"
      ];

      # checkOpts = [
      #   "--read-data"
      #   "--read-data-subset=1%"
      #   "--check-unused"
      # ];

      pruneOpts = [
        "--keep-last 10"
      ];

      backupCleanupCommand = ''
        ${notify-discord.script}/bin/notify-discord backup-server
      '';
    };

    services.restic.backups."server-data" = lib.mkIf cfg.enable-data {
      initialize = true;
      user = "root";
      repository = data-backup-folder;
      passwordFile = config.sops.secrets.restic_passwd.path;
      paths = [
        "/media/KFC/immich"
      ];
      exclude = [
        # Immich generated & cached assets (can be rebuilt anytime)
        "**/immich/thumbs/**"
        "**/immich/encoded-video/**"
        
        # General junk & caches
        "**/.cache/**"
        "**/cache/**"
        "**/tmp/**"
        "**/temp/**"
      ];

      timerConfig = {
        OnCalendar = "Sun,Wed,Fri *-*-* 03:10:00";
        Persistent = true;
      };
      
      extraOptions = [
        "--verbose"
      ];

      pruneOpts = [
        "--keep-last 3"
      ];

      # backupCleanupCommand = ''
      #   ${notify-discord.script}/bin/notify-discord backup-server
      # '';
    };
  };
}
