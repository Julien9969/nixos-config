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
      systemd.services.prowlarr.serviceConfig =  {
        ReadWritePaths = [ "/var/lib/my-config/jellyfin" ];
      };

      services.jellyfin = {
        enable = true;
        openFirewall = if cfg.enableProxy then false else true;

        user = "jellyfin"; 
        group = "jellyfin"; 

        dataDir = "/var/lib/my-config/jellyfin"; 
        configDir = "/var/lib/my-config/jellyfin/config"; 
        cacheDir = "/var/cache/my-config/jellyfin"; 
        logDir = "/var/log/jellyfin"; 
      };
      users.users.jellyfin.extraGroups = [ "media" ];
      systemd.services.jellyfin.serviceConfig.IOSchedulingPriority = 0;
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
