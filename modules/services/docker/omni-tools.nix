{ config, lib, pkgs, secrets, ... }: let mkVirtualHost = import 
  ../../../lib/mk-virtualhost; cfg = config.services.myServices.omniTools;
in { options.services.myServices.omniTools = { enable = lib.mkOption { type 
      = lib.types.bool; default = false; description = "Enable omni-tools 
      container.";
    };
    enableProxy = lib.mkOption { type = lib.types.bool; default = true; 
      description = "Enable reverse proxy for omni-tools.";
    };
  };
  config = lib.mkIf cfg.enable { 
    virtualisation.oci-containers.containers.omni-tools = {
      image = "iib0011/omni-tools:latest"; autoStart = true; 
      autoRemoveOnStop = false;
      #restartPolicy = "unless-stopped";
      ports = [ 
        "8030:80"
      ];
    };
    services.nginx.virtualHosts."omni-tools.${secrets.main_domain}" = 
      lib.mkIf cfg.enableProxy (mkVirtualHost {
        forceSSL = true; useACMEHost = secrets.main_domain; locations."/" = 
        {
          proxyPass = "http://localhost:8030"; proxyWebsockets = true;
        };
        blockCommonExploit = true; cacheAssets = true;
      });
  };
}
