# modules/services/jellyfin.nix
{ config, lib, pkgs, secrets, ... }:
let
  mkVirtualHost = (import ../../lib/mk-virtualhost);
  cfg = config.services.myServices.jellyfin;
in {
  options.services.myServices.jellyfin = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the Jellyfin media server";
    };

    enableProxy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable reverse proxy for Jellyfin";
    };
  };

  config = lib.mkMerge [
    # ── start jellyfin ──
    (lib.mkIf cfg.enable {
      services.jellyfin = {
        enable = true;
        openFirewall = if cfg.enableProxy then false else true;

        user = "jellyfin"; # User that the Jellyfin service will run as
        group = "jellyfin"; # Group for the Jellyfin service

        dataDir = "/var/lib/jellyfin"; # Default directory for media metadata and data
        cacheDir = "/var/cache/jellyfin"; # Cache directory used by Jellyfin
        configDir = "/var/lib/jellyfin/config"; # Directory for Jellyfin configuration
        logDir = "/var/log/jellyfin"; # Directory where logs are stored
      };
      users.users.jellyfin.extraGroups = [ "media" ];
    })

    # ── reverse‑proxy nginx ──
    (lib.mkIf (cfg.enable && cfg.enableProxy) {
      services.nginx.virtualHosts."jellyfin.${secrets.main_domain}" = mkVirtualHost {
        forceSSL    = true;
        useACMEHost = secrets.main_domain;

        locations."/" = {
          proxyPass = "http://localhost:8096";
          proxyWebsockets = true;
        };
        locations."/socket" = {
          proxyPass = "http://localhost:8096";
          proxyWebsockets = true;
        };

        extraConfig = ''
          proxy_buffering off;
          sendfile on;
        '';

        blockCommonExploit = true;
        cacheAssets = true;
      };
    })
  ];
}
