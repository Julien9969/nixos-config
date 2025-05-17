
{config, pkgs, lib, ...}:
let
  sonarrEnabled = config.services.myServices.servarr.enableSonarr or false;
  radarrEnabled = config.services.myServices.servarr.enableRadarr or false;
in
{
  options.services.myServices.servarr = lib.mkOption {
    default = { };
    type  = lib.types.submodule {
      options.enableSonarr = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable the Sonarr service";
      };

      options.enableRadarr = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable the Radarr service";
      };
    };
    description = "Options for Servarr-related services like Sonarr, Radarr, etc.";
  };

  config = {
    services.sonarr = lib.mkIf sonarrEnabled {
      enable = true;
      openFirewall = true;
      dataDir = "/home/trizotto/config/sonarr";
      user = "trizotto"; #! TODO not sure if correct for security
      group = "media";
    };

    services.radarr = lib.mkIf radarrEnabled {
      enable = true;
      openFirewall = true;
      dataDir = "/home/trizotto/config/radarr";
      user = "trizotto"; #! TODO not sure if correct for security
      group = "media";
    };
  };
}