{ config, pkgs, lib, secrets, ... }:
let
  mkVirtualHost = import ../../lib/mk-virtualhost;

  cfg = config.services.myServices.dashy;

  finalDrv = if cfg.settings != {} then
    cfg.package.override { inherit (cfg) settings; }
  else
    cfg.package;
in
{
  options.services.myServices.dashy = {
    enable = lib.mkEnableOption "Dashy";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.dashy-ui; 
      description = "Dashy static site package";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Optional settings to customize Dashy (e.g., YAML config)";
    };

    enableProxy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable reverse proxy for Dashy";
    }; 

    finalDrv = lib.mkOption {
      type = lib.types.package;
      internal = true;
      default = finalDrv;
      description = "Final Dashy build with optional settings override";
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx.enable = true;

    services.dashy = {
      enable = true;
      # settings = {};
      # finalDrv = finalDrv;
    };

    services.nginx.virtualHosts."dashy.${secrets.main_domain}" = lib.mkIf cfg.enableProxy ({
      forceSSL = true;
      useACMEHost = secrets.main_domain;

      locations."/" = {
        root = cfg.finalDrv;
        tryFiles = "$uri /index.html";
      };

      # extraConfig = ''
      # '';

      # blockCommonExploit = true;
      # cacheAssets = true;
    });
  };
}
