{ config, lib, pkgs, secrets, unstable-pkgs, ... }:
let
  mkVirtualHost = (import ../../lib/mk-virtualhost);
  cfg = config.services.myServices.beszel;
in {

  options.services.myServices.beszel = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the Beszel monitoring hub + agent";
    };

    enableProxy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable reverse proxy for the Beszel hub web UI";
    };

    enableAgent = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the Beszel agent (reports this host's stats to the hub)";
    };

    enableSmartmon = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable S.M.A.R.T. disk monitoring via smartctl in the agent";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      systemd.services.beszel-hub.serviceConfig = {
        StateDirectory = lib.mkForce "my-config/beszel-hub";
        RuntimeDirectory = lib.mkForce "my-config/beszel-hub";
        StateDirectoryMode = "0750";
      };

      services.beszel.hub = {
        enable = true;
        package = unstable-pkgs.beszel;
        dataDir = "/var/lib/my-config/beszel-hub";
        host = "0.0.0.0";
        port = 8090;
      };
    })

    (lib.mkIf (cfg.enable && cfg.enableAgent) {
      services.beszel.agent = {
        enable = true;
        package = unstable-pkgs.beszel;
        openFirewall = false;
        environmentFile = config.sops.secrets.beszel_agent_env_file.path;
        environment = {
          EXTRA_FILESYSTEMS = "/media/EXOS,/media/NAS,/media/DSK,/media/KFC,/media/PFK,/media/DSK";
          # LOG_LEVEL = "debug";
        };        
        #extraPath = [ pkgs.smartmontools ];
        #smartmon = lib.mkIf cfg.enableSmartmon {
        #  enable = true;
        #  deviceAllow = [];
        #};
      };
    })


    (lib.mkIf (cfg.enable && cfg.enableProxy) {
      services.nginx.virtualHosts."beszel.${secrets.main_domain}" = mkVirtualHost {
        forceSSL = true;
        useACMEHost = secrets.main_domain;
        locations."/" = {
          proxyPass = "http://localhost:8090";
          proxyWebsockets = true;
        };
        extraConfig = ''proxy_buffering off; sendfile on;'';
        blockCommonExploit = true;
        cacheAssets = true;
      };
    })
  ];
}
