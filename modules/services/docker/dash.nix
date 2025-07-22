{ config, lib, pkgs, secrets, ... }:
let
  mkVirtualHost = (import ../../../lib/mk-virtualhost);
  cfg = config.services.myServices.dash;
in
{
  options.services.myServices.dash = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable dashdot dashboard (with GPU and host mount)";
    };

    enableProxy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable reverse proxy for dash.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.dash = {
      image = "mauricenino/dashdot:nvidia";
      autoStart = true;
      autoRemoveOnStop = false;
      privileged = true;

      ports = [ "3001:3001" ];

      volumes = [
        "/:/mnt/host:ro"
      ];

      environment = {
        DASHDOT_WIDGET_LIST = "os,cpu,storage,ram,network,gpu";
      };

      extraOptions = [
        "--device" 
        "nvidia.com/gpu=all"
      ];
    };
    services.nginx.virtualHosts."dash.${secrets.main_domain}" = 
      lib.mkIf (cfg.enable && cfg.enableProxy ) (mkVirtualHost {
      forceSSL    = true;
      useACMEHost = secrets.main_domain;

      locations."/" = {
        proxyPass = "http://localhost:3001";
        proxyWebsockets = true;
      };

      blockCommonExploit = true;
      cacheAssets = true;
    });
  };
}
