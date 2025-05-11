# modules/common/firewall.nix
{ config, pkgs, ... }:
{
  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 80 443 ];
  networking.firewall.allowedUDPPorts = [ 80 443 ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
}