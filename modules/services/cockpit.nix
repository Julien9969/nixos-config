{ config, lib, pkgs, ... }:
let
  enabled = config.services.myServices.enableCockpit or false;
in
{
  options.services.myServices.enableCockpit = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable the Cockpit web interface";
  };

  config = lib.mkIf enabled {
    services.cockpit = {
      enable = true;
      port = 9090;
      openFirewall = true;
      settings.WebService.AllowUnencrypted = true;
    };
  };
}
