{ config, lib, pkgs, secrets, ... }:
let
  mkVirtualHost = (import ../../../lib/mk-virtualhost);
  cfg = config.services.myServices.cross-seed;
  qbittorrentUid = lib.attrByPath [ "users" "users" "qbittorrent" "uid" ] 1000 config;
  defaultConfig = pkgs.writeText "cross-seed-config.js" ''
    module.exports = {
      torznab: [
        "http://prowlarr:9696/1/api?apikey=CHANGE_ME",
      ],
      torrentClients: [
        "qbittorrent:http://CHANGE_ME:CHANGE_ME@localhost:8085",
      ],
      linkDirs: [
        "/media/DSK/mediaserver-data/torrents/cross-seed-links",
      ],
    };
  '';
in
{
  options.services.myServices.cross-seed = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable cross-seed docker service";
    };

    enableProxy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable reverse proxy for cross-seed";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /var/lib/my-config/cross-seed 0775 qbittorrent media - -"
      "d /var/lib/my-config/cross-seed/config 0775 qbittorrent media - -"
      "C /var/lib/my-config/cross-seed/config/config.js 0664 qbittorrent media - ${defaultConfig}"
    ];

    virtualisation.oci-containers.containers.cross-seed = {
      image = "ghcr.io/cross-seed/cross-seed:6";
      pull = "always";

      hostname = "cross-seed";
      serviceName = "cross-seed";

      # cross-seed requires the same UID/GID as the torrent client for linking.
      user = "${toString qbittorrentUid}:${toString config.users.groups.media.gid}";
      autoStart = true;
      autoRemoveOnStop = false;

      ports = [ "2468:2468" ];

      volumes = [
        "/var/lib/my-config/cross-seed/config:/config"
        "/media:/media"
      ];

      cmd = [ "daemon" ];

      extraOptions = [
        "--restart=unless-stopped"
      ];

      privileged = false;
    };

    services.nginx.virtualHosts."cross-seed.${secrets.main_domain}" =
      lib.mkIf (cfg.enable && cfg.enableProxy) (mkVirtualHost {
        forceSSL = true;
        useACMEHost = secrets.main_domain;

        locations."/" = {
          proxyPass = "http://localhost:2468";
          proxyWebsockets = true;
        };

        blockCommonExploit = true;
        cacheAssets = true;
      });
  };
}
