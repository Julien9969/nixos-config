# modules/services/entrypoint.nix
{ config, lib, pkgs, ... }:
{
  imports = [
    ../../modules/services/docker.nix
    ../../modules/services/openssh.nix
    ../../modules/services/jellyfin.nix
    # ../../modules/services/servarr.nix
    ../../modules/services/reverse-proxy.nix
    ../../modules/services/cockpit.nix
  ];  

  config.services.myServices.enableCockpit = true;
}
