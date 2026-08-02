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

  imports = 
  [
    ./crafty.nix
    ./playit.nix
    ./flaresolverr.nix
    ./fankarr.nix
    ./wizarr.nix
    ./dash.nix
    ./filebrowser-quantum.nix
    ./omni-tools.nix
  #  ./cross-seed.nix
  ];
}
