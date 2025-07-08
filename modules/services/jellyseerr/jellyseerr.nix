{config, pkgs, lib, secrets, ...}:
let
  mkVirtualHost = (import ../../lib/mk-virtualhost);
  cfg = config.services.myServices.jellyseerr;
  myConfigDir = "/var/lib/my-config/jellyseerr";
in
{
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
    # systemd.services.jellyseerr.serviceConfig = {
    #   ReadWritePaths = [ 
    #     "${myConfigDir}/config"
    #     "${myConfigDir}/logs"
    #   ];
    # };

    # systemd.tmpfiles.rules = [
    #   "d ${myConfigDir}/config 0750 - - - -"
    #   "d ${myConfigDir}/logs 0750 - - - -"
    # ];

    systemd.tmpfiles.rules = [
      "d ${myConfigDir} 0755 servarr media - -"
      "d ${myConfigDir}/config 0750 servarr media - -"
      "d ${myConfigDir}/logs 0750 servarr media - -"
      "d ${myConfigDir}/db 0750 servarr media - -"
    ];

    # Override jellyseerr systemd service user/group
    systemd.services.jellyseerr.serviceConfig = {
      User = "servarr";
      Group = "media";
      ReadWritePaths = [
        "${myConfigDir}/config"
        "${myConfigDir}/logs"
        "${myConfigDir}/db"
      ];
    };

    services.jellyseerr = {
      enable = true;
      openFirewall = if cfg.enableProxy then false else true;
      configDir = "${myConfigDir}";
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
