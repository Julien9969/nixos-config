# modules/services/qbit-run.nix
{ config, pkgs, lib, secrets, ... }:
let 
  mkVirtualHost = (import ../../lib/mk-virtualhost);
  cfg = config.services.myServices.qbittorrent-vpn;
in {
  imports =
    [
      ./qbittorrent
      ./wireguard-client
    ];

  options.services.myServices.qbittorrent-vpn = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable qBittorrent";
    };
    enableVpn = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable VPN for qBittorrent";
    };
    enableProxy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable reverse proxy for qBittorrent";
    };
  };

  config = lib.mkMerge [
    # ── start wireguard client ──
    (lib.mkIf (cfg.enable && cfg.enableVpn) {
      #! TODO: make the possibility to create multiple instances services.wireguardVpn.wg-vpn = {}
      services.wireguardVpn = {
        enable = true;
        name = "proton";
        privateKeyFile = config.sops.secrets.wg_private_key.path;
        address = "10.2.0.2/32";
        dns = [
          "9.9.9.9"
          "149.112.112.112"
          "2620:fe::9"
          "2620:fe::10"
        ];
        
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
    })

    # ── reverse‑proxy nginx ──
    (lib.mkIf (cfg.enable && cfg.enableProxy) {
      services.nginx.virtualHosts."qbittorrent.${secrets.main_domain}" = mkVirtualHost {
        forceSSL = true;
        useACMEHost = secrets.main_domain;

        locations."/" = {
          # TODO Check host with VPN to improve flexibility
          proxyPass = "http://10.200.200.1:${toString config.services.qbittorrent.webUIPort}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Referer $scheme://$host$request_uri;
            proxy_cookie_path  / "/; Secure";
          '';
        };
        blockCommonExploit = true;
        cacheAssets = true;
      };
    })

    # ── start qbittorrent ──
    (lib.mkIf (cfg.enable) {
      services.qbittorrent = {
        enable = true;
        dataDir = "/home/trizotto/qbit";
        # configDir = "";   
        # todo change user and group to qbittorrent 
        # will need ? users.users.qbittorrent.extraGroups = [ "media" ];
        user = "trizotto";
        group = "users";

        webUIPort = 8080;
        openFirewall = if cfg.enableProxy then false else true;
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
      };
    })
  ];
}