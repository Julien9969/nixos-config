{ config, pkgs, lib, secrets, ... }:
let 
  mkVirtualHost = (import ../../lib/mk-virtualhost);
  notify-qb = import ../../scripts/notify-qb.nix { inherit secrets pkgs; };
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
          "10.2.0.1"
          "1.1.1.1"
          "9.9.9.9"
          "8.8.8.8"
          # "149.112.112.112"
          # "2620:fe::9"
          # "2620:fe::10"
        ];
        
        listenPort = 51820;
        openFirewall = true; #? maybe unecessary

        peers = [
          {
            publicKey = "buYqE3X8Wf8X/v5NtHVXYgLk45+2og8MVEbgQAkEyBw="; # "YgGdHIXeCQgBc4nXKJ4vct8S0fPqBpTgk4I8gh3uMEg=";
            endpoint = "5.253.204.162:51820"; # "185.107.44.110:51820";
            allowedIPs = [ "0.0.0.0/0" "::/0" ];
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
          proxyPass = "http://10.200.200.1:${toString config.services.qbittorrent.webuiPort}";
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
        user = "qbittorrent";
        group = "media";
        profileDir = "/var/lib/my-config/qbittorrent";
        extraArgs = [
          "--confirm-legal-notice"
        ];
        webuiPort = 8085;
        # torrentingPort = 6881;
        serverConfig = {
          Application = {
            FileLogger = {
              Age = 1;
              AgeType = 1;
              Backup = true;
              DeleteOld = true;
              Enabled = true;
              MaxSizeBytes = 66560;
              Path = "/home/trizotto/qbit/config/qBittorrent/data/logs";
            };
            InstanceName = "nixtrizottoserver";
            MemoryWorkingSetLimit = 1024;
          };

          AutoRun = {
            OnTorrentAdded = {
              Enabled = true;
              Program = ''${notify-qb.script}/bin/notify-qb add \"%N\" \"%L\" \"%D\" \"%C\" \"%Z\"'';
            };
            enabled = true;
            program = ''${notify-qb.script}/bin/notify-qb done \"%N\" \"%L\" \"%D\" \"%C\" \"%T\"'';
          };

          BitTorrent = {
            MergeTrackersEnabled = true;
            Session = { 
              AddTorrentStopped = false;
              AlternativeGlobalDLSpeedLimit = 0;
              AlternativeGlobalUPSpeedLimit = 0;
              BTProtocol = "Both";
              BandwidthSchedulerEnabled = true;
              DefaultSavePath = "/media/DSK/downloads";
              DisableAutoTMMByDefault = false;
              DisableAutoTMMTriggers.CategoryChanged = true;
              ExcludedFileNames = "";
              FinishedTorrentExportDirectory = "/media/DSK/torrent-save";
              GlobalDLSpeedLimit = 40000;
              GlobalUPSpeedLimit = 4000;
              IgnoreSlowTorrentsForQueueing = true;
              Interface = "wg-proton";
              InterfaceAddress = "10.2.0.2";
              InterfaceName = "wg-proton";
              MaxActiveCheckingTorrents = 3;
              MaxActiveDownloads = 7;
              MaxActiveTorrents = 999;
              MaxActiveUploads = 10;
              MaxConnections = 400;
              MaxConnectionsPerTorrent = 100;
              MaxUploads = 20;
              MaxUploadsPerTorrent = 5;
              PerformanceWarning = false;
              Port = 6881;
              Preallocation = true;
              QueueingSystemEnabled = false;
              ReannounceWhenAddressChanged = true;
              SSL.Port = 33753;
              ShareLimitAction = "Stop";
              SlowTorrentsDownloadRate = 75;
              SlowTorrentsUploadRate = 25;
              SubcategoriesEnabled = true;
              Tags = "Serie";
              UseAlternativeGlobalSpeedLimit = false;
              UseCategoryPathsInManualMode = true;
              ValidateHTTPSTrackerCertificate = true;
            };
          };

          Core = {
            AutoDeleteAddedTorrentFile = "IfAdded";
          };

          LegalNotice.Accepted = true;
          Meta.MigrationVersion = 8;

          Network = {
            PortForwardingEnabled = "";
            Proxy = { 
              HostnameLookupEnabled = false;
              Profiles = { 
                BitTorrent = true;
                Misc = true;
                RSS = true;
              };
            };
          };

          Preferences = {
            General = {
              DeleteTorrentsFilesAsDefault = true;
              Locale = "en";
              StatusbarExternalIPDisplayed = true;
            };
            Scheduler = {
              end_time = "@Variant(\\0\\0\\0\\xf\\x1\\xee\\x62\\x80)";
              start_time = "@Variant(\\0\\0\\0\\xf\\0m\\xdd\\0)";
            };
            WebUI = {
              CSRFProtection = "";
              Password_PBKDF2 = "@ByteArray(LhKP3TEq5kbzfwklH5W0zQ==:OeWrH5CZsGvlOUgd/IPV8cv5HRBp2Na6wfL2oIXlxlQq4VpPyYKFDqcxgA9c8BbqQtELjGD6yk10XyjuOGgQ1A==)";
              Port = 8085;
              ReverseProxySupportEnabled = true;
              TrustedReverseProxiesList = "127.0.0.0/26";
              Username = "Trizotto";
            };
          };

          RSS = {
            AutoDownloader = {
              DownloadRepacks = true;
              EnableProcessing = true;
            };
            Session = {
              EnableProcessing = true;
              RefreshInterval = 45;
            };
          };
        };
        openFirewall = if cfg.enableProxy then false else true;
      };
    })
  ];
}
