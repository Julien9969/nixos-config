{ config, lib, pkgs, secrets, ... }:
let
  notify-backup = import ../../scripts/notify-backup.nix { inherit secrets pkgs; };
  cfg = config.services.myServices.restic-backup;
  backup-folder = "/media/DSK/backups/restic";
in
{
  options.services.myServices.restic-backup = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable restic backup service";
    };
  };

  config = {
    services.restic.backups."server-config" = lib.mkIf cfg.enable {
      initialize = true;
      user = "root";
      repository = backup-folder;
      passwordFile = config.sops.secrets.restic_passwd.path;
      paths = [
        "/home/trizotto/compose-files"
        "/var/lib/my-config"
      ];
      exclude = [
        "**/.cache/**"
        "**/node_modules/**"
        "**/jellyfin/metadata/**"
        "**/jellyfin/data/subtitles/**"
        "**/jellyfin/data/keyframes/**"
        "**/logs/**"
        "**/qBittorrent/cache/**"
      ];
      timerConfig = {
        OnCalendar = "Sun *-*-* 03:00:00"; # "weeks"; 
        Persistent = true;
      };
      extraOptions = [
        "--verbose"
      ];
      backupCleanupCommand = ''
        ${pkgs.restic}/bin/restic forget --keep-last 3 --prune --repo ${backup-folder} --password-file ${config.sops.secrets.restic_passwd.path}
        ${notify-backup.script}/bin/notify-backup backup-server
      '';
    };
  };
}