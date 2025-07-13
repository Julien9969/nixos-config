{ config, pkgs, ... }:
{
  virtualisation = {
    docker = {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };

      rootless = {
        enable = true;
      };
    };
  };

  virtualisation.oci-containers.backend = "docker";

  imports = 
  [
    ./flaresolverr.nix
    ./wizarr.nix
  ];
}