
{config, pkgs, lib, secrets, ...}:
let
  mkVirtualHost = (import ../../../lib/mk-virtualhost);
  cfg = config.services.myServices.servarr;

  proxyExtraConfig = ''
    proxy_read_timeout 3600s;
    proxy_connect_timeout 3600s;
    proxy_send_timeout 3600s;
  '';
in
{
  disabledModules = [ "services/misc/servarr/prowlarr.nix" ];
  imports =
    [
      ./prowlarr.nix
    ];

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
    systemd.services.sonarr.serviceConfig = lib.mkIf cfg.enableSonarr {
      ReadWritePaths = [ "/var/lib/my-config/sonarr" ];
    };

    systemd.services.radarr.serviceConfig = lib.mkIf cfg.enableRadarr {
      ReadWritePaths = [ "/var/lib/my-config/radarr" ];
    };

    systemd.services.prowlarr.serviceConfig = lib.mkIf cfg.enableProwlarr {
      ReadWritePaths = [ "/var/lib/my-config/prowlarr" ];
    };

    systemd.tmpfiles.rules = lib.mkIf (cfg.enableRadarr || cfg.enableSonarr || cfg.enableProwlarr) [
      "d /var/lib/my-config/radarr 0750 servarr media - -"
      "d /var/lib/my-config/sonarr 0750 servarr media - -"
      "d /var/lib/my-config/prowlarr 0750 servarr media - -"
    ];
    
    services.sonarr = lib.mkIf cfg.enableSonarr {
      enable = true;
      openFirewall = if cfg.enableProxy then false else true;
      dataDir = "/var/lib/my-config/sonarr";
      user = "servarr"; 
      group = "media";
      settings = {
        update = {
          mechanism = "builtIn";
          automatically = false; # TRUE not working because can't access nix store
        };
      };
    };

    systemd.services.sonarr = {
      after = [ "prowlarr.service" ];
    };

    services.radarr = lib.mkIf cfg.enableRadarr {
      enable = true;
      openFirewall = if cfg.enableProxy then false else true;
      dataDir = "/var/lib/my-config/radarr";
      user = "servarr"; 
      group = "media";
      settings = {
        update = {
          mechanism = "builtIn";
          automatically = false;
        };
      };
    };

    systemd.services.radarr = {
      after = [ "prowlarr.service" ];
    };

    services.prowlarr = lib.mkIf cfg.enableProwlarr {
      enable = true;
      openFirewall = if cfg.enableProxy then false else true;
      dataDir = "/var/lib/my-config/prowlarr";
      user = "servarr"; 
      group = "media";
      settings = {
        update = {
          mechanism = "builtIn";
          automatically = false;
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