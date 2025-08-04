{ config, pkgs, lib, ... }:
let 
  selectedVpn = if true 
    then 
      config.services.wireguardVpn.exposed."proton" 
    else 
      null;
in {
  # Make sure resolvconf path exists
  systemd.tmpfiles.rules = [ "d /run/resolvconf 0755 root root" ];

  systemd.services.qbittorrent = {
    bindsTo = [ "wireguard-${selectedVpn.interface}.service" ];
    after = [ "wireguard-${selectedVpn.interface}.service" ];
    requires = [ "wireguard-${selectedVpn.interface}.service" ];

    serviceConfig = {
      NetworkNamespacePath = "/run/netns/${selectedVpn.namespace}";

      InaccessiblePaths = [
        "/run/nscd"
        "/run/resolvconf"
      ];

      BindReadOnlyPaths = [
        "/etc/netns/${selectedVpn.namespace}/resolv.conf:/etc/resolv.conf:norbind"
      ];
    };
  };
}