{ config, pkgs, lib, ... }:

let
  cfg = config.services.qbittorrent;

  # Configuration update script - runs before starting qBittorrent
  qbitConfigUpdateScript = "${pkgs.bash}/bin/bash ${pkgs.writeShellScript "update-qbittorrent-conf" ''
    #!/usr/bin/env bash

    CONFIG_FILE="${cfg.configDir}/qBittorrent/config/qBittorrent.conf"
    TEMP_FILE=$(mktemp)
    trap 'rm -f "$TEMP_FILE"' EXIT INT TERM
    cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
    cp "$CONFIG_FILE" "$TEMP_FILE"

    edit_conf() {
      local section="$1"
      local key_prefix="$2"
      local value="$3"

      local escaped_key_prefix=$(printf '%s' "$key_prefix" | sed 's/\\/\\\\/g')
      local full_key="$escaped_key_prefix$value"

      local operation=""

      if grep -q "^\[$section\]" "$TEMP_FILE"; then
        if grep -q "^$escaped_key_prefix" "$TEMP_FILE"; then
          if grep -q "^$full_key$" "$TEMP_FILE"; then
            operation="$section/$key_prefix : No change"
          elif [[ $key_prefix == "WebUI\\Password_PBKDF2="* || $key_prefix == "WebUI\\Username="* ]]; then
            operation="$section/$key_prefix : No change, avoid resetting password to default" 
          else
            sed -i "s|^$escaped_key_prefix.*|$full_key|" "$TEMP_FILE"
            operation="$section/$key_prefix : Updated existing key"
          fi
        else
          sed -i "/^\[$section\]/a $full_key" "$TEMP_FILE"
          operation="$section/$key_prefix : Added key"
        fi
      else
        {
          echo ""
          echo "[$section]"
          echo "$key_prefix$value"
        } >> "$TEMP_FILE"
        operation="$section/$key_prefix : Created section and added key"
      fi

      echo "[edit_conf] $operation"
    }

    # [Application]
    edit_conf Application "MemoryWorkingSetLimit=" "${toString cfg.application.memoryWorkingSetLimit}"

    # [AutoRun]
    ${lib.optionalString (cfg.autorun.onTorrentAdded) ''
      edit_conf AutoRun "OnTorrentAdded\\Enabled=" "${toString cfg.autorun.onTorrentAdded}"
      edit_conf AutoRun "OnTorrentAdded\\Program=" "${cfg.autorun.onTorrentAddedCommand}"
    ''}

    ${lib.optionalString (cfg.autorun.onDownloadEnd) ''
      edit_conf AutoRun "enabled=" "${toString cfg.autorun.onDownloadEnd}"
      edit_conf AutoRun "program=" "${cfg.autorun.onDownloadEndCommand}"
    ''}

    # [BitTorrent]
    edit_conf BitTorrent "Session\\AlternativeGlobalDLSpeedLimit=" "${toString cfg.bittorrent.alternativeGlobalDLSpeedLimit}"
    edit_conf BitTorrent "Session\\AlternativeGlobalUPSpeedLimit=" "${toString cfg.bittorrent.alternativeGlobalUPSpeedLimit}"
    edit_conf BitTorrent "Session\\GlobalUPSpeedLimit=" "${toString cfg.bittorrent.globalUPSpeedLimit}"
    edit_conf BitTorrent "Session\\GlobalDLSpeedLimit=" "${toString cfg.bittorrent.globalDLSpeedLimit}"
    edit_conf BitTorrent "Session\\BandwidthSchedulerEnabled=" "${toString cfg.bittorrent.bandwidthSchedulerEnabled}"
    edit_conf BitTorrent "Session\\BTProtocol=" "${cfg.bittorrent.btProtocol}"
    edit_conf BitTorrent "Session\\DefaultSavePath=" "${cfg.bittorrent.defaultSavePath}"

    ${lib.optionalString (cfg.bittorrent.finishedTorrentExportDirectory != null) ''
      edit_conf BitTorrent "Session\\FinishedTorrentExportDirectory=" "${cfg.bittorrent.finishedTorrentExportDirectory}"
    ''}
    
    edit_conf BitTorrent "Session\\Interface=" "${cfg.bittorrent.interface}"
    edit_conf BitTorrent "Session\\InterfaceName=" "${cfg.bittorrent.interface}"
    edit_conf BitTorrent "Session\\InterfaceAddress=" "${cfg.bittorrent.interfaceAddress}"
    edit_conf BitTorrent "Session\\Port=" "${toString cfg.bittorrent.listeningPort}"
    edit_conf BitTorrent "Session\\MaxUploadsPerTorrent=" "${toString cfg.bittorrent.maxslotsUploadSlotsPerTorrent}"
    edit_conf BitTorrent "Session\\MaxConnections=" "${toString cfg.bittorrent.maxConnections}"
    edit_conf BitTorrent "Session\\MaxConnectionsPerTorrent=" "${toString cfg.bittorrent.maxConnectionsPerTorrent}"
    edit_conf BitTorrent "Session\\MaxUploads=" "${toString cfg.bittorrent.maxUploadSlots}"
    
    ${lib.optionalString (cfg.bittorrent.queueingSystem.enabled) ''
      edit_conf BitTorrent "Session\\QueueingSystemEnabled=" "${toString cfg.bittorrent.queueingSystem.enabled}"
      edit_conf BitTorrent "Session\\MaxActiveDownloads=" "${toString cfg.bittorrent.queueingSystem.maxActiveDownloads}"
      edit_conf BitTorrent "Session\\MaxActiveTorrents=" "${toString cfg.bittorrent.queueingSystem.maxActiveTorrents}"
      edit_conf BitTorrent "Session\\MaxActiveUploads=" "${toString cfg.bittorrent.queueingSystem.maxActiveUploads}"
    ''}

    # [Network]
    edit_conf Network "PortForwardingEnabled=" "${toString cfg.network.portForwardingUpnP}"

    # [LegalNotice]
    edit_conf LegalNotice "Accepted=" "${toString cfg.legalNotice.accepted}"

    # [Preferences]
    edit_conf Preferences "General\\Locale=" "${cfg.preferences.generalLocale}"
    edit_conf Preferences "WebUI\\Password_PBKDF2=" "\"${cfg.preferences.webUIPassword}\""
    edit_conf Preferences "WebUI\\Username=" "${cfg.preferences.webUIUsername}"
    
    mv "$TEMP_FILE" "$CONFIG_FILE"
  ''}";
in
{
  options.services.qbittorrent = {

    enable = lib.mkEnableOption "qBittorrent-nox daemon";

    package = lib.mkPackageOption pkgs "qbittorrent-nox" {
      extraDescription = "Allow choosing qbittorrent pkgs, typically 'qbittorrent-nox' for headless server.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "qbittorrent";
      description = "User account under which qBittorrent runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "qbittorrent";
      description = "Group under which qBittorrent runs.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/qbittorrent";
      description = "Directory where qBittorrent stores runtime data (e.g., .torrent files, resume data, logs).";
    };

    configDir = lib.mkOption {
      type = lib.types.path;
      default = "${cfg.dataDir}/config";
      description = "Directory qBittorrent uses as profile path. qBittorrent.conf will be in '{configDir}/qBittorrent/config/qBittorrent.conf'.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall port for qBittorrent WebUI.";
    };

    webUIPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port to acces WebUI. Port openned in firewall if openFirewall is true.";
    };

    application = {
      memoryWorkingSetLimit = lib.mkOption {
        type = lib.types.int;
        default = 512;
        description = "Memory working set limit. (MB)";
      };
    };

    bittorrent = {
      globalDLSpeedLimit = lib.mkOption {
        type = lib.types.int;
        default = 1;
        description = "Global download speed limit. (KiB/s)";
      };

      globalUPSpeedLimit = lib.mkOption {
        type = lib.types.int;
        default = 1;
        description = "Global upload speed limit. (KiB/s)";
      };

      alternativeGlobalDLSpeedLimit = lib.mkOption {
        type = lib.types.int;
        default = 1;
        description = "Alternative global download speed limit. (KiB/s)";
      };

      alternativeGlobalUPSpeedLimit = lib.mkOption {
        type = lib.types.int;
        default = 1;
        description = "Alternative global upload speed limit. (KiB/s)";
      };

      bandwidthSchedulerEnabled = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''Enable bandwidth scheduler.
          This allows you schedule alternative bandwidth limit based on time condition.
          Defaut time is 08:00 to 23:59 every day, edit trough UI Options -> Speed.
        '';
      };

      btProtocol = lib.mkOption {
        type = lib.types.enum [ "Both" "TCP" "UTP" ];
        default = "Both";
        description = "BitTorrent protocol preference (Both, TCP, or UTP).";
      };

      defaultSavePath = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.dataDir}/downloads";
        description = "Default save path for torrents.";
      };

      finishedTorrentExportDirectory = lib.mkOption {
        type = lib.types.str;
        default = null;
        description = "Directory where finished .torrents are exported.";
      };

      interface = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = '''
          Network interface to bind to.
          If WireGuard VPN is used, this will be overridden by the VPN interface.
        ''; # TODO : voir avec VPN
      };

      interfaceAddress = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          Network interface address to bind to.
          If WireGuard VPN is used, this will be overridden by the VPN interface address.
        ''; # TODO : voir avec VPN
      };

      listeningPort = lib.mkOption {
        type = lib.types.int;
        default = 6881;
        description = ''
          Listening port for BitTorrent connections.
          If portforwarding is enabled with the VPN, this will be managed by the service.
        ''; # TODO : voir avec VPN
      };

      maxConnections = lib.mkOption {
        type = lib.types.int;
        default = 500;
        description = "Maximum global connections.";
      };

      maxConnectionsPerTorrent = lib.mkOption {
        type = lib.types.int;
        default = 100;
        description = "Maximum connections per torrent.";
      };

      maxUploadSlots = lib.mkOption {
        type = lib.types.int;
        default = 20;
        description = "Maximum global uploads slots.";
      };

      maxslotsUploadSlotsPerTorrent = lib.mkOption {
        type = lib.types.int;
        default = 4;
        description = "Maximum uploads slots per torrent.";
      };

      queueingSystem =  {
        enabled = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable queueing system.";
        };

        maxActiveTorrents = lib.mkOption {
          type = lib.types.int;
          default = 5;
          description = "Maximum active torrents.";
        };

        maxActiveDownloads = lib.mkOption {
          type = lib.types.int;
          default = 3;
          description = "Maximum active downloads.";
        };

        maxActiveUploads = lib.mkOption {
          type = lib.types.int;
          default = 3;
          description = "Maximum active uploads.";
        };
      };
    };

    autorun = {
      onDownloadEnd = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "AutoRun OnDownloadEnd Enabled flag.";
      };

      onDownloadEndCommand = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "CMD to run on download end.";
      };

      onTorrentAdded = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "AutoRun OnTorrentAdded Enabled flag.";
      };

      onTorrentAddedCommand = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "CMD to run on torrent added.";
      };
    };

    legalNotice = {
      accepted = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Accept the legal notice. This remove startup message.";
      };
    };

    network = {
      portForwardingUpnP = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Enable UPnP/NAT-PMP port forwarding.
        '';
      };
    };

    preferences = {
      generalLocale = lib.mkOption {
        type = lib.types.str;
        default = "en";
        description = "System language.";
      };

      webUIPassword = lib.mkOption {
        type = lib.types.str;
        # Password hash for password "adminadmin"
        default = "@ByteArray(aC7urQszTj4nSgIbyuNHOQ==:pFK6dz68n76GPdiBaerbCdaKXzj/p5u7UQCxmIg2wKN5SQtKSN/pyq5g4PMv6G2cVurO79GyWrkEnJjldPSQJA==)";
        description = ''
          Web UI password PBKDF2 hash. (default: adminadmin)
          This value will be set on the first run of qBittorrent then setted value will be kept.
        '';
      };

      webUIUsername = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "Web UI username.";
      };
    };
  };

  config = lib.mkIf cfg.enable {

    users.users = lib.mkIf (cfg.user == "qbittorrent") {
      qbittorrent = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.dataDir;
      };
    };

    users.groups = lib.mkIf (cfg.group == "qbittorrent") {
      qbittorrent = {};
    };

    # # Create directories with correct permissions
    # systemd.tmpfiles.rules = [
    #   "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} - -"
    #   "d ${cfg.configDir} 0750 ${cfg.user} ${cfg.group} - -"
    #   "d ${cfg.configDir}/qBittorrent 0750 ${cfg.user} ${cfg.group} - -"
    #   "d ${cfg.configDir}/qBittorrent/config 0750 ${cfg.user} ${cfg.group} - -"
    # ];

    systemd.services.qbittorrent = {
      description = "qBittorrent Daemon";
      after = [ "network.target" ] ++ [ "wireguard-wg-vpn.target" ]; # TODO lib.optional cfg.vpn.enable , "network-online.target" 
      requires = [ "wireguard-wg-vpn.service" ]; # wait for the VPN to be up
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        UMask = "0002";
       
        # Run configuration update script before starting qbittorrent
        ExecStartPre = [ "${qbitConfigUpdateScript}" ];

        ExecStart = 
        let 
          legalNotice = if cfg.legalNotice.accepted == true then "--confirm-legal-notice " else "";
        in 
        ''
          ${pkgs.iproute2}/bin/ip netns exec vpn-ns ${lib.getExe cfg.package} --profile=${cfg.configDir} --webui-port=${toString cfg.webUIPort} ${legalNotice}
        '';# ${cfg.vpn.namespace}

        CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_SYS_ADMIN" ];
        AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_SYS_ADMIN" ];
        
        Restart = "on-failure";
        RestartSec = "10s";
      };
      #! TODO VPN
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.webUIPort ];
    };
  };
}
