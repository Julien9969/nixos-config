{ config, lib, pkgs, secrets, ... }:
{
  imports = [
    ./services/docker
    ./services/openssh.nix
    ./services/jellyfin.nix
    ./services/servarr
    ./services/jellyseerr
    ./services/reverse-proxy.nix
    ./services/cockpit.nix
    ./services/qbittorrent-vpn.nix
    ./services/zipline.nix
    ./services/filebrowser.nix
    ./services/minecraft-neoforge.nix
    ./services/restic.nix
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
  
  config.services.myServices.servarr = {
    enableSonarr = true;
    enableRadarr = true;
    enableProwlarr = true;
    enableProxy = true;
  };

  config.services.myServices.jellyseerr = {
    enable = true;
    enableProxy = true; 
  };

  config.services.myServices.filebrowser = {
    enable = true;
    enableProxy = true;
  };

  config.services.myServices.restic-backup.enable = true;
  
  config.services.myServices.enableZipline = false;
}
