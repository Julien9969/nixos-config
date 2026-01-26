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
  hardware.nvidia-container-toolkit.enable = true;

  imports = 
  [
    ./flaresolverr.nix
    ./wizarr.nix
    ./dash.nix
    ./filebrowser-quantum.nix
    ./omni-tools.nix
    ./ygege.nix
  ];
}
