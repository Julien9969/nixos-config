# modules/services/filebrowser.nix
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
    };

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
