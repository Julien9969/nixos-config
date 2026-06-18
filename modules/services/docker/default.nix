{ config, pkgs, ... }:
{
  virtualisation = {
    docker = {
      enable = true;
      package = pkgs.docker_29;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };

      rootless = {
        enable = true;
        package = pkgs.docker_29;
      };
    };
  };

  virtualisation.oci-containers.backend = "docker";
  hardware.nvidia-container-toolkit.enable = true;

  imports = 
  [
    ./crafty.nix
    ./playit.nix
    ./flaresolverr.nix
    ./wizarr.nix
    ./dash.nix
    ./filebrowser-quantum.nix
    ./omni-tools.nix
    ./ygege.nix
  #  ./cross-seed.nix
  ];
}
