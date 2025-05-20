# modules/services/qbit-run.nix
{ config, pkgs, ... }:

{
  imports =
    [
      ./qbittorrent
      ./wireguard-client
    ];

  #! TODO: make the possibility to create multiple instances services.wireguardVpn.wg-vpn = {}
  services.wireguardVpn = {
    enable = true;
    name = "proton";
    privateKeyFile = config.sops.secrets.wg_private_key.path;
    address = "10.2.0.2/32";
    dns = "10.2.0.1";
    listenPort = 51820;
    openFirewall = true;

    peers = [
      {
        publicKey = "YgGdHIXeCQgBc4nXKJ4vct8S0fPqBpTgk4I8gh3uMEg=";
        endpoint = "185.107.44.110:51820";
        allowedIPs = [ "0.0.0.0/0" ];
        persistentKeepalive = 25;
      }
    ];
  };

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
      # interface = "";
      # interfaceAddress = "";
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
      generalLocale = "fr";
      webUIPassword = "@ByteArray(LhKP3TEq5kbzfwklH5W0zQ==:OeWrH5CZsGvlOUgd/IPV8cv5HRBp2Na6wfL2oIXlxlQq4VpPyYKFDqcxgA9c8BbqQtELjGD6yk10XyjuOGgQ1A==)";
      webUIUsername="Trizotto";
    };

    vpn = {
      enable = true;
      instanceName = "proton";
      portforwarding = false;
    };

    legalNotice.accepted = true;
    openFirewall = true;
  };
}