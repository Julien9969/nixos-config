# modules/common/docker.nix
{ config, pkgs, ... }:
{
  virtualisation.docker.enable = true;
}