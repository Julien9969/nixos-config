{ config, pkgs, ... }:
{
  networking.nameservers = [
    "9.9.9.9"
    "149.112.112.112"
    "2620:fe::9"
    "2620:fe::10"
  ];

  # Set manualy lan adress because it broken with DHCP for some reason 
  networking.interfaces.enp3s0f1 = {
    ipv4.addresses = [{
      address = "192.168.1.200";
      prefixLength = 24;
    }];
  };

  networking.networkmanager.dns = "none"; # Empêche NM de gérer le DNS
  
  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 443 ];
  networking.firewall.allowedUDPPorts = [ 443 ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
}