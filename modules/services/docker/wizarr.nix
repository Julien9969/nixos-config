{ config, lib, secrets, ... }:
let
  mkVirtualHost = (import ../../../lib/mk-virtualhost);
  cfg = config.services.myServices.wizarr;
in
{
  options.services.myServices.wizarr = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable wizarr docker service";
    };

    enableProxy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable reverse proxy for wizarr";
    };
  };

  config = lib.mkIf cfg.enable {

    systemd.tmpfiles.rules = [
      "d /var/lib/my-config/wizarr 0775 servarr media - -"
      "d /var/lib/my-config/wizarr/database 0775 servarr media - -"
      "d /var/lib/my-config/wizarr/data 0775 servarr media - -"
    ];
    
    virtualisation.oci-containers.containers.wizarr = {
      image = "ghcr.io/wizarrrr/wizarr:latest";
      pull = "always";

      hostname = "wizarr";
      serviceName = "wizarr";
      user = "${toString config.users.users.servarr.uid}:${toString config.users.groups.media.gid}";
      autoStart = true;
      autoRemoveOnStop = false;

      environment = {
        PUID = "${toString config.users.users.servarr.uid}";
        PGID = "${toString config.users.groups.media.gid}";
        TZ = "Europe/London";
        DISABLE_BUILTIN_AUTH = "false";
      };

      ports = [ "5690:5690" ];
      # networks = [];

      volumes = [
        "/var/lib/my-config/wizarr/database:/data/database"
        "/var/lib/my-config/wizarr/data:/data/wizard_steps"
      ];

      extraOptions = [ 
        "--memory=512m" 
        "--tmpfs=/.cache:exec,mode=0777"
        # "--add-host=host.docker.internal:172.17.0.1" # firewalled
      ];

      privileged = false;
    };

    services.nginx.virtualHosts."wizarr.${secrets.main_domain}" = 
      lib.mkIf (cfg.enable && cfg.enableProxy ) (mkVirtualHost {
      forceSSL    = true;
      useACMEHost = secrets.main_domain;

      locations."/" = {
        proxyPass = "http://localhost:5690";
        proxyWebsockets = true;
      };

      blockCommonExploit = true;
      cacheAssets = true;
    });
  };
}