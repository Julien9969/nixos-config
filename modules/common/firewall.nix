{ config, pkgs, lib, ... }:

{
  # networking.useDHCP = false;
  networking.nameservers = [ "9.9.9.9" ];
  networking.enableIPv6 = false;

  # Keep networkd: Proxmox writes the container's IP/gateway as networkd config.
  networking.useNetworkd = lib.mkForce true;
  # WireGuard lifecycle hooks and interface namespaces need the scripted
  # backend, so only WireGuard opts out of networkd.
  networking.wireguard.useNetworkd = false;

  # # === Ethernet (LAN) - Primary ===
  # networking.interfaces.enp3s0f1 = {
  #   ipv4.addresses = [{
  #     address = "192.168.1.200";
  #     prefixLength = 24;
  #   }];
    
  #   ipv4.routes = [{
  #     address = "0.0.0.0";
  #     prefixLength = 0;
  #     via = "192.168.1.254";
  #     options = { metric = "100"; }; # Lower number = higher priority
  #   }];
  # };

  services.resolved = {
    enable = true;
    dnssec = "true";
    dnsovertls = "true";
    fallbackDns = [ "1.1.1.1" "1.0.0.1" ];
    # settings.Resolve = {
    #   Cache = true;
    #   CacheFromLocalhost = true;
    # };
  };

  networking.firewall = {
    enable = false;
    trustedInterfaces = [ "eth0" ];
    
    allowedTCPPorts = [ 80 443 554 ];
    allowedUDPPorts = [ 443 554 ];
  };
}