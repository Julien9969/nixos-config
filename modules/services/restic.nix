{ config, lib, pkgs, secrets, ... }:
let
  notify-discord = import ../../scripts/notify-discord.nix { inherit secrets pkgs; };
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
        "${config.users.users.trizotto.home}/.config/sops/age/keys.txt"
        "${config.users.users.trizotto.home}/.ssh"
        "/etc/nixos"
      ];
      exclude = [
        "**/.cache/**"
        "**/cache/**"
        "**/node_modules/**"
        "**.bak"
        "**/jellyfin/metadata/**"
        "**/jellyfin/data/subtitles/**"
        "**/jellyfin/data/keyframes/**"
        "**/jellyfin/data/introskipper/chromaprints/**"
        "**/jellyfin/data/attachments/**"
        "**/MediaCover/**"
        "**/logs/**"
        "**/qBittorrent/cache/**"
      ];
      timerConfig = {
        OnCalendar = "Sun,Wed,Fri *-*-* 03:00:00";
        Persistent = true;
      };
      extraOptions = [
        "--verbose"
      ];

      pruneOpts = [
        "--keep-last 5"
      ];

      backupCleanupCommand = ''
        # ${pkgs.restic}/bin/restic forget --keep-last 5 --prune --repo ${backup-folder} --password-file ${config.sops.secrets.restic_passwd.path}
        ${notify-discord.script}/bin/notify-discord backup-server
      '';
    };
  };
}
