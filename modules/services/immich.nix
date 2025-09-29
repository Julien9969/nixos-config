{ config, lib, pkgs, secrets, ... }:
let
  mkVirtualHost = (import ../../lib/mk-virtualhost);
  cfg = config.services.myServices.immich;
in
{
  options.services.myServices.immich = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable immich service";
    };

    enableProxy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable reverse proxy for immich";
    };
  };

  config = {
    services.immich = {
    enable = true;

    user = "immich";
    group = "media";

    port = 2283;
    # host = "0.0.0.0";
    # openFirewall = true;

    # Répertoires
    mediaLocation = "/media/DSK/immich";

    # secretsFile = "/var/lib/immich/secrets.env";

    # database = {
    #   enable = true;
    #   createDB = true;
    #   enableVectors = true;
    #   enableVectorChord = false;
    #   host = "127.0.0.1";
    #   port = 5432;
    #   name = "immich";
    #   user = "immich";
    # };

    accelerationDevices = [
      "/dev/dri/renderD129"
    ];

    machine-learning = {
      enable = true;
      environment = {};
    };

    settings.server.externalDomain = "https://immich.${secrets.main_domain}";
  };

  services.nginx.virtualHosts."immich.${secrets.main_domain}" = 
    lib.mkIf (cfg.enable && cfg.enableProxy ) (mkVirtualHost {
      forceSSL    = true;
      useACMEHost = secrets.main_domain;

      locations."/" = {
        proxyPass = "http://localhost:2283";
        proxyWebsockets = true;
      };

      extraConfig = '''';

      blockCommonExploit = true;
      cacheAssets = true;
    });
  };
}

