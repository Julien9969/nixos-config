{ config, lib, secrets, ... }:
let
  cfg = config.services.myServices.playit;
in
{
  options.services.myServices.playit = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Playit docker service";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.playit = {
      image = "ghcr.io/playit-cloud/playit-agent:0.17";
      pull = "always";

      hostname = "playit";
      serviceName = "playit";
      autoStart = true;
      autoRemoveOnStop = false;

      environment = {
        SECRET_KEY = secrets.playitgg_secret_key;
      };

      extraOptions = [
        "--network=host"
      ];

      privileged = false;
    };
  };
}