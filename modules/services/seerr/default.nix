{config, pkgs, unstable-pkgs, lib, secrets, ...}:
let
  mkVirtualHost = (import ../../../lib/mk-virtualhost);
  cfg = config.services.myServices.seerr;
in
{
  disabledModules = [ "services/misc/seerr.nix" ];
  imports = 
    [
      ./seerr.nix
    ];
  
  options.services.myServices.seerr = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Seerr service";
    };

    enableProxy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable reverse proxy for Seerr";
    };
  };

  config = lib.mkIf cfg.enable {
    services.seerr = {
      enable = true;
      package = unstable-pkgs.seerr;
      openFirewall = if cfg.enableProxy then false else true;
      configDir = "/var/lib/my-config/seerr";
    };

    services.nginx.virtualHosts."seerr.${secrets.main_domain}" = 
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

    services.nginx.virtualHosts."jellyseerr.${secrets.main_domain}" =
      lib.mkIf (cfg.enable && cfg.enableProxy) (mkVirtualHost {
      forceSSL = true;
      useACMEHost = secrets.main_domain;
      globalRedirect = "seerr.${secrets.main_domain}";
    });
  };
}
