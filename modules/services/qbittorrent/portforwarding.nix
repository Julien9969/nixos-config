{ selectedVpn, pkgs, lib, ... }:
{
  systemd.services.natpmp-keepalive = {
    description = "Keep NAT-PMP port mapping alive for qBittorrent";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "qbittorrent.service" ];
    bindsTo = [ "qbittorrent.service" ];
    
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 10;
      ExecStart = pkgs.writeShellScript "natpmp-keepalive" ''
        set -eu
        while true; do
          echo "[NAT-PMP] $(date)"
          ${pkgs.libnatpmp}/bin/natpmpc -a 1 0 udp 60 -g 10.2.0.1
          ${pkgs.libnatpmp}/bin/natpmpc -a 1 0 tcp 60 -g 10.2.0.1
          sleep 45
        done
      '';

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