
{config, pkgs, lib, secrets, ...}:
let
  mkVirtualHost = (import ../../lib/mk-virtualhost);
  cfg = config.services.myServices.servarr;

  proxyExtraConfig = ''
    proxy_read_timeout 3600s;
    proxy_connect_timeout 3600s;
    proxy_send_timeout 3600s;
  '';
in
{
  options.services.myServices.servarr = lib.mkOption {
    default = { };
    type  = lib.types.submodule {
      options.enableSonarr = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable the Sonarr service";
      };

      options.enableRadarr = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable the Radarr service";
      };

      options.enableProwlarr = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable the Prowlarr service";
      };

      options.enableProxy = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable reverse proxy for servarr services";
      };
    };
    description = "Options for Servarr-related services like Sonarr, Radarr, etc.";
  };

  config = {
    services.sonarr = lib.mkIf cfg.enableSonarr {
      enable = true;
      openFirewall = if cfg.enableProxy then false else true;
      dataDir = "/home/trizotto/config/sonarr";
      user = "trizotto"; #! TODO not sure if correct for security
      group = "media";
      settings = {
        update = {
          mechanism = "builtIn";
          automatically = true;
        };
      };
    };

    services.radarr = lib.mkIf cfg.enableRadarr {
      enable = true;
      openFirewall = if cfg.enableProxy then false else true;
      dataDir = "/home/trizotto/config/radarr";
      user = "trizotto"; #! TODO not sure if correct for security
      group = "media";
      settings = {
        update = {
          mechanism = "builtIn";
          automatically = true;
        };
      };
    };

    services.prowlarr = lib.mkIf cfg.enableProwlarr {
      enable = true;
      openFirewall = if cfg.enableProxy then false else true;
      dataDir = "/home/trizotto/config/prowlarr";
      settings = {
        update = {
          mechanism = "builtIn";
          automatically = true;
        };
      };
    };

    services.nginx.virtualHosts."sonarr.${secrets.main_domain}" = 
      lib.mkIf (cfg.enableSonarr && cfg.enableProxy ) (mkVirtualHost {
      forceSSL    = true;
      useACMEHost = secrets.main_domain;

      locations."/" = {
        proxyPass = "http://localhost:8989";
        proxyWebsockets = true;
      };

      extraConfig = proxyExtraConfig;

      blockCommonExploit = true;
      cacheAssets = true;
    });

    services.nginx.virtualHosts."radarr.${secrets.main_domain}" = 
      lib.mkIf (cfg.enableRadarr && cfg.enableProxy ) (mkVirtualHost {
      forceSSL    = true;
      useACMEHost = secrets.main_domain;

      locations."/" = {
        proxyPass = "http://localhost:7878";
        proxyWebsockets = true;
      };

      extraConfig = proxyExtraConfig;

      blockCommonExploit = true;
      cacheAssets = true;
    });

    services.nginx.virtualHosts."prowlarr.${secrets.main_domain}" = 
      lib.mkIf (cfg.enableProwlarr && cfg.enableProxy ) (mkVirtualHost {
      forceSSL    = true;
      useACMEHost = secrets.main_domain;

      locations."/" = {
        proxyPass = "http://localhost:9696";
        proxyWebsockets = true;
      };

      extraConfig = proxyExtraConfig;

      blockCommonExploit = true;
      cacheAssets = true;
    });
  };
}