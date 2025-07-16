{config, pkgs, lib, secrets, ...}:
let
  mkVirtualHost = (import ../../../lib/mk-virtualhost);
  cfg = config.services.myServices.jellyseerr;
in
{
  disabledModules = [ "services/misc/jellyseerr.nix" ];
  imports = 
    [
      ./jellyseerr.nix
    ];
  
  options.services.myServices.jellyseerr = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Jellyseer service";
    };

    enableProxy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable reverse proxy for Jellyseer";
    };
  };

  config = lib.mkIf cfg.enable {
    services.jellyseerr = {
      enable = true;
      openFirewall = if cfg.enableProxy then false else true;
      configDir = "/var/lib/my-config/jellyseerr";
    };

    services.nginx.virtualHosts."jellyseerr.${secrets.main_domain}" = 
      lib.mkIf (cfg.enable && cfg.enableProxy ) (mkVirtualHost {
      forceSSL    = true;
      useACMEHost = secrets.main_domain;

      locations."/" = {
        proxyPass = "http://localhost:5055";
        proxyWebsockets = true;
      };

      blockCommonExploit = true;
      cacheAssets = true;
    });
  };
}
