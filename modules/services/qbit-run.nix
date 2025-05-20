{ config, pkgs, ... }:

{
  imports =
    [
      ../../modules/services/qbittorrent 
    ];

  services.qbittorrent = {
    enable = true;
    dataDir = "/home/trizotto/qbit";
    # configDir = "";
    user = "trizotto"; 
    group = "users"; 
    
    webUIPort = 8080;

    application.memoryWorkingSetLimit = 512;

    bittorrent = {
      listeningPort = 6881;
      globalDLSpeedLimit = 40000;
      globalUPSpeedLimit = 3000;
      alternativeGlobalDLSpeedLimit = 0;
      alternativeGlobalUPSpeedLimit = 10000;
      bandwidthSchedulerEnabled = true;
      btProtocol = "Both";
      interface = "wg-vpn";
      interfaceAddress = "10.2.0.2";
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

    network.portForwardingUpnP = false;

    autorun = {
      onDownloadEnd = true;
      onDownloadEndCommand = "echo 'Download finished!'";

      onTorrentAdded = true;
      onTorrentAddedCommand = "echo 'Torrent added!'";
    };

    preferences = {
      generalLocale = "en";
      webUIPassword = "@ByteArray(LhKP3TEq5kbzfwklH5W0zQ==:OeWrH5CZsGvlOUgd/IPV8cv5HRBp2Na6wfL2oIXlxlQq4VpPyYKFDqcxgA9c8BbqQtELjGD6yk10XyjuOGgQ1A==)";
      webUIUsername="Trizotto";
    };

    vpn = {
      enable = true;
      wg-interface = "wg-vpn";
      namespace = "vpn-ns";
      wg-address = "10.2.0.2/32";
      dns = "10.2.0.1";
      portforwarding = false;
      privateKeyFile = config.sops.secrets.wg_private_key.path;

      peers = [
        {
          publicKey = "YgGdHIXeCQgBc4nXKJ4vct8S0fPqBpTgk4I8gh3uMEg=";
          endpoint = "185.107.44.110:51820";
          allowedIPs = [ "0.0.0.0/0" ];
        }
      ];
    };

    legalNotice.accepted = true;
    openFirewall = true;
  };

  networking.firewall = {
    allowedUDPPorts = [ 51820 ]; # Clients and peers can use the same port, see listenport
  };

  environment.etc."netns/vpn-ns/resolv.conf".text = "nameserver 10.2.0.1";

  networking.wireguard.enable = true;
  networking.wireguard.interfaces.wg-vpn = {
    ips = [ "10.2.0.2/32" ]; 
    
    privateKeyFile = config.sops.secrets.wg_private_key.path;
    # privateKey = "";

    listenPort = 51820;

    interfaceNamespace = "vpn-ns"; 

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
      
      # Bring up the veth interfaces
      ip link set veth-host up
      ip -n vpn-ns link set veth-vpn up
    '';

    postSetup = ''
      # Force the veth-vpn interface to be the default route for the namespace
      ip -n vpn-ns route add default dev wg-vpn
    '';

    postShutdown = ''
      # Delete the veth pair
      ip link del veth-host || true
      ip netns del vpn-ns || true # Delete the all namespace
    '';

    peers = [
      {
        publicKey = "YgGdHIXeCQgBc4nXKJ4vct8S0fPqBpTgk4I8gh3uMEg=";

        # Forward all the traffic via VPN.
        # allowedIPs = [ "0.0.0.0/0" ]; # "::/0" 
        allowedIPs = ["0.0.0.0/0"]; #"::/0"];
        endpoint = "185.107.44.110:51820"; 
        persistentKeepalive = 25;
      }
    ];
  };
}
