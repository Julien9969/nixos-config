# modules/services/entrypoint.nix
{ config, lib, pkgs, secrets, ... }:
{
  imports = [
    ../../modules/services/docker.nix
    ../../modules/services/openssh.nix
    ../../modules/services/jellyfin.nix
    ../../modules/services/servarr.nix
    ../../modules/services/reverse-proxy
    ../../modules/services/cockpit.nix
    ../../modules/services/qbit-run.nix
    ../../modules/services/zipline.nix
  ];  

  config.services.myServices.enableCockpit = builtins.trace secrets false;
  config.services.myServices.enableJellyfin = true;
  config.services.myServices.servarr.enableSonarr = false;
  config.services.myServices.servarr.enableRadarr = false;  
  config.services.myServices.enableZipline = false;
}
