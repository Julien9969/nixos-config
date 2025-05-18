{ config, pkgs, ... }:

{
  imports =
    [
      ../../modules/services/qbittorrent.nix # Path to your new module
    ];

  # ... other configurations ...

  services.qbittorrent = {
    enable = true;
    dataDir = "/home/trizotto/qbit";
    # configDir = "";
    user = "trizotto"; 
    group = "users"; 
    
    webUIPort = 8080;

    bittorrent = {
      listeningPort = 6881;
      globalDLSpeedLimit = 40000;
      globalUPSpeedLimit = 3000;
      alternativeGlobalDLSpeedLimit = 0;
      alternativeGlobalUPSpeedLimit = 10000;
      bandwidthSchedulerEnabled = true;
      btProtocol = "Both";
      interface = "wg-vpn";
      defaultSavePath = "/media/HDD/Downloads";
      finishedTorrentExportDirectory = "/media/HDD/Downloads/Finished";

      maxConnections = 500;
      maxConnectionsPerTorrent = 100;
      maxUploadSlots = 20;
      maxslotsUploadSlotsPerTorrent = 4;

      queueingSystem = {
        enabled = false;
        maxActiveTorrents = 5;
        maxActiveDownloads = 3;
        maxActiveUploads = 3;
      };
    };

    autorun = {
      onDownloadEnd = true;
      onDownloadEndCommand = "echo 'Download finished!'";

      onTorrentAdded = true;
      onTorrentAddedCommand = "echo 'Torrent added!'";
    };

    preferences = {
      generalLocale = "fr";
      webUIPassword = "@ByteArray(LhKP3TEq5kbzfwklH5W0zQ==:OeWrH5CZsGvlOUgd/IPV8cv5HRBp2Na6wfL2oIXlxlQq4VpPyYKFDqcxgA9c8BbqQtELjGD6yk10XyjuOGgQ1A==)";
      webUIUsername="Trizotto";
    };

    legalNotice.accepted = true;
    openFirewall = true;
  };

  networking.firewall = {
    allowedTCPPorts = [ 51820 ]; # Web UI port
    allowedUDPPorts = [ 51820 ]; # Clients and peers can use the same port, see listenport
  };

  environment.etc."netns/vpn-ns/resolv.conf".text = "nameserver 1.1.1.1";
  # sudo ip netns exec vpn-ns curl https://api.ipify.org
  # Example WireGuard setup that uses the same namespace
  # This assumes you have a wireguard.nix or similar
  networking.wireguard.interfaces.wg-vpn = {
    # ... your WireGuard private key, peer public key, endpoint ...
    ips = [ "10.2.0.2/32" ]; # Example VPN IP #! pas sur de ça
    
    privateKeyFile = config.sops.secrets.wg_private_key.path;
    # privateKey = "";

    listenPort = 51820;

    # CRITICAL: Assign WireGuard interface to the namespace
    interfaceNamespace = "vpn-ns"; # Must match services.qbittorrent.vpn.namespace

    # WireGuard module might handle namespace creation/deletion
    # If so, services.qbittorrent.vpn.manageNamespaceLifecycle should be false.
    # The tutorial's example had preSetup/postShutdown for namespace and veth.
    # If WireGuard handles namespace creation, its preSetup could be:
    preSetup = ''
      if ip netns list | grep -q vpn-ns; then
        ip netns del vpn-ns || true
        ip link del veth-host || true
      fi
      
      # Creates a new network namespace (check: ip netns)
      ip netns add vpn-ns || true
      # Brings loopback interface for internal networking in ns (check: sudo ip netns exec vpn-ns ip a)
      ip -n vpn-ns link set lo up

      # # Create a veth pair for the host and the namespace (like a virtual ethernet cable)
      ip link add veth-host type veth peer name veth-vpn
      # Send the veth-vpn end to the namespace
      ip link set veth-vpn netns vpn-ns

      # assign IP addresses to the veth interfaces
      ip addr add 10.200.200.1/24 dev veth-host
      ip -n vpn-ns addr add 10.200.200.2/24 dev veth-vpn
      
      # Bring up the veth interfaces on the host
      ip link set veth-host up
      # Bring up the loopback and veth interfaces in the namespace 
      # ip -n vpn-ns link set wg-vpn up
      ip -n vpn-ns link set lo up
      ip -n vpn-ns link set veth-vpn up

      # ip -n vpn-ns route add default via 10.200.200.1
      # ip -n vpn-ns route add default dev wg-vpn

      ${pkgs.iptables}/bin/iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 10.200.200.2:8080
      ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -j MASQUERADE
      # # ip netns exec vpn-ns ip route add default via 10.200.200.1
    '';

    postSetup = ''
      ${pkgs.iptables}/bin/iptables -A FORWARD -i wg-vpn -j ACCEPT
      ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.10.0.0/24 -o wlp2s0 -j MASQUERADE
      ip -n vpn-ns link set wg-vpn up
      ip -n vpn-ns route add default dev wg-vpn
    '';

    postShutdown = ''
      ${pkgs.iptables}/bin/iptables -D FORWARD -i wg-vpn -j ACCEPT
      ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.10.0.0/24 -o wlp2s0 -j MASQUERADE

      #${pkgs.iptables}/bin/iptables -t nat -D PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 10.200.200.2:8080
      #${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -j MASQUERADE
      
      # Delete the veth pair
      ip link del veth-host || true
      ip netns del vpn-ns || true # Delete the all namespace
    '';

 #? start
    # sudo ip netns exec vpn-ns your-app2-command --port=8080

# preSetup = ''
#   if ! ip netns list | grep -q vpn-ns; then
#     ip netns add vpn-ns
#   fi
#   ip -n vpn-ns link set lo up
# '';

# postShutdown = ''
#   if ip netns list | grep -q vpn-ns; then
#     ip netns del vpn-ns
#   fi
# '';
    peers = [
      # For a client configuration, one peer entry for the server will suffice.
      {
        # Public key of the server (not a file path).
        publicKey = "DznTG0WjFUlvggmQ9FsoUvbrU6D9zz1YgdRImKR/+18=";

        # Forward all the traffic via VPN.
        # allowedIPs = [ "0.0.0.0/0" ]; # "::/0" 
        allowedIPs = ["0.0.0.0/0" "::/0"];
        # dns = [ "1.1.1.1" "1.0.0.1" ];

        # Or forward only particular subnets
        #allowedIPs = [ "10.100.0.1" "91.108.12.0/22" ];

        # Set this to the server IP and port.
        endpoint = "169.150.218.90:51820"; # ToDo: route to endpoint not automatically configured https://wiki.archlinux.org/index.php/WireGuard#Loop_routing https://discourse.nixos.org/t/solved-minimal-firewall-setup-for-wireguard-client/7577

        # Send keepalives every 25 seconds. Important to keep NAT tables alive.
        persistentKeepalive = 25;
      }
    ];
    # The qBittorrent module will then handle its veth pair within this namespace.
  };
  
#   networking.wireguard.interface.wg-mullvad = {
#   # Use a separate network namespace for the VPN.
#   # sudo ip netns exec wg-qbittorrent curl --interface wg-mullvad https://am.i.mullvad.net/connected

#   privateKey = "my-private-key";
#   ips = ["my-ip"];
#   interfaceNamespace = "wg-qbittorrent";

#   preSetup = ''
# 	ip netns add wg-qbittorrent
# 	ip -n wg-qbittorrent link set lo up
#   '';

#   postShutdown = ''
# 	ip netns delete wg-qbittorrent
#   '';
	
#   peers = [
#     {
#       publicKey = "the-public-key";
#       allowedIPs = ["0.0.0.0/0" "::0/0"];
#       endpoint = "the-endpoint";
#     }
#   ];
# };

  # Ensure the qbittorrent service user can write to download paths
  # systemd.tmpfiles.rules = [
  #   "d /mnt/storage/torrents/downloading 0775 your-media-user your-media-group - -"
  #   "d /mnt/storage/torrents/incomplete 0775 your-media-user your-media-group - -"
  # ];
}

# https://github.com/notthebee/nix-config/blob/94ec3a147f93d4f017fbde6e7e961569b48aff4d/homelab/services/wireguard-netns/default.nix