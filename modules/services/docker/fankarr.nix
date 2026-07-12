{ config, lib, secrets, ... }:
let
  mkVirtualHost = import ../../../lib/mk-virtualhost;
  cfg = config.services.myServices.fankarr;
  dataDir = "/var/lib/my-config/fankarr";
  tz = if config.time.timeZone != null then config.time.timeZone else "Etc/UTC";
in
{
  options.services.myServices.fankarr = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable FanKarr docker service";
    };

    enableProxy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable reverse proxy for FanKarr";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${dataDir} 2775 servarr media - -"
      "d ${dataDir}/config 2775 servarr media - -"
      "d ${dataDir}/logs 2775 servarr media - -"
    ];

    virtualisation.oci-containers.containers.fankarr = {
      image = "masutayunikon/fankarr:latest";
      pull = "always";

      hostname = "fankarr";
      serviceName = "fankarr";
      autoStart = true;
      autoRemoveOnStop = false;

      environment = {
        PUID = "${toString config.users.users.servarr.uid}";
        PGID = "${toString config.users.groups.media.gid}";
        TZ = tz;
        PORT = "9898";
      };

      ports = [ "9898:9898" ];

      volumes = [
        "${dataDir}/config:/config"
        "${dataDir}/logs:/config/logs"
        "/media:/media"
      ];

      extraOptions = [
        "--memory=1024m"
      ];

      privileged = false;
    };

    services.nginx.virtualHosts."fankarr.${secrets.main_domain}" =
      lib.mkIf (cfg.enable && cfg.enableProxy) (mkVirtualHost {
        forceSSL = true;
        useACMEHost = secrets.main_domain;

        locations."/" = {
          proxyPass = "http://localhost:9898";
          proxyWebsockets = true;
        };

        blockCommonExploit = true;
        cacheAssets = true;
      });
  };
}