# modules/common/firewall.nix
{ config, pkgs, ... }:
{
  networking.nameservers = [
    "9.9.9.9"
    "149.112.112.112"
    "2620:fe::9"
    "2620:fe::10"
  ];
  networking.networkmanager.dns = "none"; # Empêche NM de gérer le DNS
  
  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 80 443 ];
  networking.firewall.allowedUDPPorts = [ 80 443 ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
}