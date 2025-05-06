# modules/common/nix.nix
{ config, pkgs, ... }:
{
  # Enable flakes and experimental Nix features globally
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Allow unfree packages globally
  nixpkgs.config.allowUnfree = true;
}