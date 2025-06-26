# modules/services/entrypoint.nix
{ config, lib, pkgs, secrets, ... }:
{
  imports = [
    ../../modules/services/docker.nix
    ../../modules/services/openssh.nix
    ../../modules/services/jellyfin.nix
    ../../modules/services/servarr.nix
    ../../modules/services/reverse-proxy.nix
    ../../modules/services/cockpit.nix
    ../../modules/services/qbittorrent-vpn.nix
    ../../modules/services/zipline.nix
    ../../modules/services/minecraft-neoforge.nix
  ];  

  # TODO remove logs after dev
  config.services.myServices.enableCockpit = builtins.trace secrets false;

  config.services.minecraft-neoforge.enable = false;
  
  config.services.myServices.jellyfin = {
    enable = true;
    enableProxy = true; 
  };

  config.services.myServices.qbittorrent-vpn = {
    enable = true;
    enableVpn = true;
    enableProxy = true;
  };
  
  config.services.myServices.servarr.enableSonarr = false;
  config.services.myServices.servarr.enableRadarr = false;  
  config.services.myServices.enableZipline = false;
}
