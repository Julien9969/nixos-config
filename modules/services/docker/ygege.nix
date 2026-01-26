{ config, lib, secrets, ... }:
let
  mkVirtualHost = (import ../../../lib/mk-virtualhost);
  cfg = config.services.myServices.ygege;
in
{
  options.services.myServices.ygege = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Ygégé (YGG proxy) docker service";
    };

    enableProxy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable reverse proxy for Ygégé";
    };
  };

  config = lib.mkIf cfg.enable {

    systemd.tmpfiles.rules = [
      "d /var/lib/my-config/ygege 0775 servarr media - -"
      "d /var/lib/my-config/ygege/config 0775 servarr media - -"
    ];

    virtualisation.oci-containers.containers.ygege = {
      image = "uwucode/ygege:latest";
      pull = "always";

      hostname = "ygege";
      serviceName = "ygege";

      # same pattern as your wizarr service
      user = "${toString config.users.users.root.uid}:${toString config.users.groups.media.gid}";
      autoStart = true;
      autoRemoveOnStop = false;

      environment = {
        YGG_USERNAME = secrets.ygg.username;
        YGG_PASSWORD = secrets.ygg.password;

        BIND_IP = "0.0.0.0";
        BIND_PORT = "8715";
        LOG_LEVEL = "debug";
      };

      ports = [ "8715:8715" ];

      volumes = [
        "/var/lib/my-config/ygege/config:/config"
      ];

      extraOptions = [
        "--memory=256m"
        #"--tmpfs=/tmp:exec,mode=1777"
      ];

      privileged = false;
    };

    services.nginx.virtualHosts."ygege.${secrets.main_domain}" =
      lib.mkIf cfg.enableProxy (mkVirtualHost {
        forceSSL    = true;
        useACMEHost = secrets.main_domain;

        locations."/" = {
          proxyPass = "http://localhost:8715";
          proxyWebsockets = false;
        };

        blockCommonExploit = true;
        cacheAssets = false;
      });
  };
}
