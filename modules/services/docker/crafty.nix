{ config, lib, secrets, ... }:
let
  mkVirtualHost = (import ../../../lib/mk-virtualhost);
  cfg = config.services.myServices.crafty;
  dataDir = "/var/lib/my-config/crafty";
  tz = if config.time.timeZone != null then config.time.timeZone else "Etc/UTC";
in
{
  options.services.myServices.crafty = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Crafty docker service";
    };

    enableProxy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable reverse proxy for Crafty";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${dataDir} 2775 root root - -"
      "d ${dataDir}/backups 2775 root root - -"
      "d ${dataDir}/logs 2775 root root - -"
      "d ${dataDir}/servers 2775 root root - -"
      "d ${dataDir}/config 2775 root root - -"
      "d ${dataDir}/import 2775 root root - -"
    ];

    virtualisation.oci-containers.containers.crafty = {
      image = "registry.gitlab.com/crafty-controller/crafty-4:latest";
      pull = "always";

      hostname = "crafty";
      serviceName = "crafty";
      autoStart = true;
      autoRemoveOnStop = false;

      environment = {
        TZ = tz;
      };

      ports = [
        "8443:8443"
        "8123:8123"
        "19132:19132/udp"
        "25500-25600:25500-25600"
      ];

      volumes = [
        "${dataDir}/backups:/crafty/backups"
        "${dataDir}/logs:/crafty/logs"
        "${dataDir}/servers:/crafty/servers"
        "${dataDir}/config:/crafty/app/config"
        "${dataDir}/import:/crafty/import"
      ];

      privileged = false;
    };

    services.nginx.virtualHosts."crafty.${secrets.main_domain}" =
      lib.mkIf (cfg.enable && cfg.enableProxy) (mkVirtualHost {
        forceSSL    = true;
        useACMEHost = secrets.main_domain;

        locations."/" = {
          proxyPass = "https://localhost:8443";
          proxyWebsockets = true;
        };

        extraConfig = ''
          proxy_ssl_verify off;
        '';

        blockCommonExploit = true;
        cacheAssets = false;
      });
  };
}
