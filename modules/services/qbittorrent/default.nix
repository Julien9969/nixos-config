{ config, pkgs, lib, ... }:
let 
  selectedVpn = if true 
    then 
      config.services.wireguardVpn.exposed."proton" 
    else 
      null;
in {
  imports =
  [
    (import ./portforwarding.nix { inherit selectedVpn pkgs lib; })
  ];

  # Make sure resolvconf path exists
  systemd.tmpfiles.rules = [ "d /run/resolvconf 0755 root root" ];

  systemd.services.qbittorrent-firewall = {
    description = "qBittorrent firewall and NAT-PMP setup";
    wantedBy = [ "qbittorrent.service" ];
    after = [ "wireguard-${selectedVpn.interface}.service" ];
    before = [ "qbittorrent.service" ];
    
    serviceConfig = {
      Type = "oneshot";
      NetworkNamespacePath = "/run/netns/${selectedVpn.namespace}";
      InaccessiblePaths = [
        "/run/nscd"
        "/run/resolvconf"
      ];

      BindReadOnlyPaths = [
        "/etc/netns/${selectedVpn.namespace}/resolv.conf:/etc/resolv.conf:norbind"
      ];
      ExecStart = pkgs.writeShellScript "qbittorrent-firewall" ''
        set -euo pipefail

        echo [PortForward] Retrieve forwarded port

        port=""
        vpnIP=""

        for i in {1..5}; do
          natpmp_out="$(${pkgs.libnatpmp}/bin/natpmpc -a 1 0 udp 60 -g 10.2.0.1 || true)"
          port="$(printf '%s\n' "$natpmp_out" | ${pkgs.gawk}/bin/awk '/Mapped public port/ {print $4}')"
          if [ -n "$port" ]; then
            echo "Using NAT-PMP port: $port"
            if grep -q '^Session\\Port=' /var/lib/my-config/qbittorrent/qBittorrent/config/qBittorrent.conf; then
              sed -i -r "s/^(Session\\\\Port=).*/\\1$port/" /var/lib/my-config/qbittorrent/qBittorrent/config/qBittorrent.conf
            else
              echo "Session\\Port=$port" >> /var/lib/my-config/qbittorrent/qBittorrent/config/qBittorrent.conf
            fi
          else
            echo "[WARN] Failed to retrieve port"
          fi

          vpnIP="$(printf '%s\n' "$natpmp_out" | ${pkgs.gawk}/bin/awk -F': ' '/Public IP address/ { print $2 }' | tr -d '\n')"
          if [ -n "$vpnIP" ]; then
            echo "VPN IP: $vpnIP"
          else
            echo "[ERROR] Failed to retrieve vpn IP"
          fi

          if [ -n "$port" ] && [ -n "$vpnIP" ]; then
            echo "[INFO] Successfully retrieved port and VPN IP, exiting loop."
            break
          fi

          sleep 5
        done

        if [ -z "$port" ] || [ -z "$vpnIP" ]; then
          echo "[ERROR] NAT-PMP negotiation failed; refusing to start qBittorrent without a valid forwarded port."
          exit 1
        fi

        ${pkgs.iptables}/bin/iptables -F
        ${pkgs.iptables}/bin/iptables -P INPUT DROP
        ${pkgs.iptables}/bin/iptables -P FORWARD DROP
        ${pkgs.iptables}/bin/iptables -P OUTPUT DROP

        ${pkgs.iptables}/bin/iptables -A INPUT -i lo -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A INPUT -p icmp --icmp-type echo-reply -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        
        ${pkgs.iptables}/bin/iptables -A INPUT -i ${selectedVpn.interface} -p tcp --dport $port -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A INPUT -i ${selectedVpn.interface} -p udp --dport $port -j ACCEPT

        ${pkgs.iptables}/bin/iptables -A OUTPUT -o lo -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A OUTPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A OUTPUT -o ${selectedVpn.interface} -j ACCEPT

        # Allow reverse proxy access from host namespace over the veth link
        ${pkgs.iptables}/bin/iptables -A INPUT -i vt-${selectedVpn.namespace} -p tcp --dport 8085 -j ACCEPT
      '';
    };
  };


  systemd.services.qbittorrent = {
    bindsTo = [ "wireguard-${selectedVpn.interface}.service" ];
    after = [ 
      "wireguard-${selectedVpn.interface}.service" 
      "qbittorrent-firewall.service" 
    ];

    requires  = [ 
      "qbittorrent-firewall.service" 
    ];
    
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