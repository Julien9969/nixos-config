{ config, pkgs, ... }:
{
  networking.useDHCP = false;

  networking.interfaces.enp3s0f1 = {
    ipv4.addresses = [{
      address = "192.168.1.200";
      prefixLength = 24;
    }];
    ipv6.addresses = [{
      address = "2a01:e0a:99b:8820::200"; 
      prefixLength = 64;
    }];
  };

  networking.nameservers = [ "1.1.1.1#one.one.one.one" "1.0.0.1#one.one.one.one" ];

  services.resolved = {
    enable = true;
    dnssec = "true";
    domains = [ "~." ];
    fallbackDns = [ "1.1.1.1#one.one.one.one" "1.0.0.1#one.one.one.one" ];
    dnsovertls = "true";
  };

  networking.interfaces.wlp2s0.useDHCP = true;

  networking.defaultGateway = { 
    address =  "192.168.1.254";
    interface = "enp3s0f1";
  };

  # Needed for rstp live TV
  networking.firewall.trustedInterfaces = [ "enp3s0f1" ];

  networking.firewall = {
    enable = true;
    # 80 & 443 : nginx
    # 554 : rstp (live tv)
    allowedTCPPorts = [ 80 443 554];
    allowedUDPPorts = [ 443 554 ]; 
  };
}