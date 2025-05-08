# modules/services/docker.nix
{ config, pkgs, ... }:
{
  virtualisation.docker.enable = true;
}