{ config, lib, pkgs, secrets, ... }:
let
  mkVirtualHost = (import ../../lib/mk-virtualhost);
  cfg = config.services.myServices.filebrowser;
in
{
  options.services.myServices.filebrowser = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Filebrowser service";
    };

    enableProxy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable reverse proxy for Filebrowser";
    };
  };

  config = {
    services.filebrowser = lib.mkIf cfg.enable {
      enable = true;

      user = "filebrowser";
      group = "media";
      settings=  {
        root = "/media";
        database = "/var/lib/my-config/filebrowser/database.db";
      };

      openFirewall = if cfg.enableProxy then false else true;
    };

    # Filebrowser rules breaks other services access to /media
    systemd.tmpfiles.settings.filebrowser = lib.mkForce {};

    services.nginx.virtualHosts."filebrowser.${secrets.main_domain}" = 
      lib.mkIf (cfg.enable && cfg.enableProxy ) (mkVirtualHost {
      forceSSL    = true;
      useACMEHost = secrets.main_domain;

      locations."/" = {
        proxyPass = "http://localhost:8080";
        proxyWebsockets = true;
      };

      extraConfig = '''';

      blockCommonExploit = true;
      cacheAssets = true;
    });
  };
}
