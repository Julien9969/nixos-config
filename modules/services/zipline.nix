# modules/services/zipline.nix
{ config, lib, pkgs, ... }:
let
  enabled = config.services.myServices.enableZipline or false;
in
{
  options.services.myServices.enableZipline = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = '''
      Enable the Zipline service
      https://zipline.diced.sh/
    '';
  };

  config = lib.mkIf enabled {
    services.zipline = {
      enable = true;
      settings = {
        CORE_HOSTNAME = "0.0.0.0";
        CORE_PORT = 3000;
        CORE_SECRET = "Secret (echo -n \"xxx\" | md5sum)";
        DATASOURCE_LOCAL_DIRECTORY = "/var/lib/zipline/uploads";
        DATASOURCE_TYPE = "local";
      };
    };

    networking.firewall = {
      allowedTCPPorts = [ 3000 ];
    };
  };
}