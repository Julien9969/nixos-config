# modules/common/nix.nix
{ config, pkgs, ... }:
{
  # Autormove nix stuff after sometimes
  nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
  };

  nix.package = pkgs.nixVersions.stable;
  
  # Enable flakes and experimental Nix features globally
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  # Allow unfree packages globally
  nixpkgs.config.allowUnfree = true;
}