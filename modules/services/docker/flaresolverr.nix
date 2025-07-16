{ config, lib, ... }:
let
  cfg = config.services.myServices.flaresolverr;
in
{
  options.services.myServices.flaresolverr = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable flaresolverr docker service";
    };
  };
  
  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.flaresolverr = {
      # image = "ghcr.io/flaresolverr/flaresolverr:latest";
      image = "21hsmw/flaresolverr:nodriver";
      # image = "alexfozor/flaresolverr:pr-1300-experimental"; # some errors happen
      pull = "always";

      hostname = "flaresolverr";
      serviceName = "flaresolverr";
      autoStart = true;
      autoRemoveOnStop = false;

      environment = {
        CAPTCHA_SOLVER = "none"; # hcaptcha-solver 
        LOG_HTML = "false";
        LOG_LEVEL = "info";
        TZ = "Europe/London";
        BROWSER_TIMEOUT = "2000";
        NAME_SERVERS = "1.1.1.1";
        DRIVER = "nodriver";
      };

      ports = [ "8191:8191" ];

      extraOptions = [ 
        "--memory=512m"
        "--dns=1.1.1.1"
      ];
      privileged = false;
    };
  };
}