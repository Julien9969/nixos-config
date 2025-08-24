{ config, lib, secrets, ... }:
let
  mkVirtualHost = (import ../../../lib/mk-virtualhost);
  cfg = config.services.myServices.filebrowser-quantum;
in
{
  options.services.myServices.filebrowser-quantum = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Filebrowser docker service";
    };

    enableProxy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable reverse proxy for Filebrowser";
    };
  };

  config = lib.mkIf cfg.enable {

    systemd.tmpfiles.rules = [
      "d /var/lib/my-config/filebrowser-quantum 0775 servarr media - -"
      "d /var/lib/my-config/filebrowser-quantum/data 0775 servarr media - -"
    ];

    virtualisation.oci-containers.containers.filebrowser = {
      image = "gtstef/filebrowser:latest";
      pull = "always";

      hostname = "filebrowser-quantum";
      serviceName = "filebrowser-quantum";

      # run as media group
      user = "${toString config.users.users.root.uid}:${toString config.users.groups.media.gid}";
      autoStart = true;

      environment = {
        FILEBROWSER_CONFIG = "/home/filebrowser/data/config.yaml";
        FILEBROWSER_ADMIN_PASSWORD = "admin";
        TZ = "Europe/Paris";
      };

      ports = [ "8091:80" ];

      volumes = [
        "/media:/media"
        "/var/lib/my-config/filebrowser-quantum/data:/home/filebrowser/data"
      ];

      extraOptions = [
        "--memory=512m"
      ];

      privileged = false;
    };

    services.nginx.virtualHosts."files.${secrets.main_domain}" =
      lib.mkIf (cfg.enable && cfg.enableProxy) (mkVirtualHost {
        forceSSL    = true;
        useACMEHost = secrets.main_domain;

        locations."/" = {
          proxyPass = "http://localhost:8091";
          proxyWebsockets = true;
        };

        blockCommonExploit = true;
        cacheAssets = true;
      });
  };
}
