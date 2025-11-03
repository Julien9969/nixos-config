{ config, pkgs, ... }:

{
  networking.useDHCP = false;
  networking.nameservers = [ "1.1.1.1" "1.0.0.1" ];
  networking.enableIPv6 = false;

  # === Ethernet (LAN) - Primary ===
  networking.interfaces.enp3s0f1 = {
    ipv4.addresses = [{
      address = "192.168.1.200";
      prefixLength = 24;
    }];
    
    ipv4.routes = [{
      address = "0.0.0.0";
      prefixLength = 0;
      via = "192.168.1.254";
      options = { metric = "100"; }; # Lower number = higher priority
    }];
  };

  # === Wi-Fi (Fallback) ===
  networking.interfaces.wlp2s0 = {
    useDHCP = true;
  };

  services.resolved = {
    enable = true;
    dnssec = "true";
    dnsovertls = "true";
    fallbackDns = [ "8.8.4.4" ];
  };

  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "enp3s0f1" ];
    
    allowedTCPPorts = [ 80 443 554 ];
    allowedUDPPorts = [ 443 554 ];
  };
}