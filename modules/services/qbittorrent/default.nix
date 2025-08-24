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
        echo [PortForward] Retrieve forwarded port
        port=$(${pkgs.libnatpmp}/bin/natpmpc -a 1 0 udp 60 -g 10.2.0.1 | ${pkgs.gawk}/bin/awk '/Mapped public port/ {print $4}')
        if [ -n "$port" ]; then
          echo "Using NAT-PMP port: $port"
          sed -i -r "s/^(Session\\\\Port=).*/\\1$port/" /var/lib/my-config/qbittorrent/qBittorrent/config/qBittorrent.conf
          cat 
        else
          echo "[WARN] Failed to retrieve port"
          port=6881
        fi
        vpnIP=$(${pkgs.libnatpmp}/bin/natpmpc -a 1 0 udp 60 -g 10.2.0.1 | ${pkgs.gawk}/bin/awk -F': ' '/Public IP address/ { print $2 }' | tr -d '\n')
        if [ -n "$vpnIP" ]; then
          echo "VPN IP: $vpnIP"
        else
          echo "[ERROR] Failed to retrieve vpn IP"
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
        
        ${pkgs.iptables}/bin/iptables -t filter -A INPUT -p tcp --dport $port -j ACCEPT
        ${pkgs.iptables}/bin/iptables -t filter -A INPUT -p udp --dport $port -j ACCEPT
        
        ${pkgs.iptables}/bin/iptables -A OUTPUT -o lo -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A OUTPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A OUTPUT -p udp -d $vpnIP --dport 51820 -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A OUTPUT -o ${selectedVpn.interface} -j ACCEPT

        # Allow incoming TCP connections on port 8085 from veth interface in the namespace
        ${pkgs.iptables}/bin/iptables -A INPUT -i vt-${selectedVpn.namespace} -p tcp --dport 8085 -j ACCEPT

        # Allow incoming TCP connections on port 8085 from host side veth interface
        ${pkgs.iptables}/bin/iptables -A INPUT -i vt-host-${selectedVpn.namespace} -p tcp --dport 8085 -j ACCEPT

        # Allow outgoing traffic to return
        ${pkgs.iptables}/bin/iptables -A OUTPUT -o vt-${selectedVpn.namespace} -j ACCEPT
        ${pkgs.iptables}/bin/iptables -A OUTPUT -o vt-host-${selectedVpn.namespace} -j ACCEPT
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