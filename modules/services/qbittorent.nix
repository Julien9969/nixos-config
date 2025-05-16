# qbittorrent.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.services.qbittorrent;

  # Function to generate qBittorrent.conf content dynamically
  # Based on the tutorial's generateConfig snippet
  generateConfigLines = attrs:
    lib.concatStringsSep "\n\n" (
      lib.mapAttrsToList (
        section: keys: let
          lines = lib.mapAttrsToList (
            key: value: "${key}=${
              if lib.isBool value then (if value then "true" else "false")
              else if lib.isList value then lib.concatStringsSep ", " (map toString value)
              else toString value
            }"
          ) (lib.filterAttrs (_: v: v != null) keys); # Filter out null key-values within a section
        in
          if lines == []
          then "" # Don't output section if all its keys were null
          else "[${section}]\n" + lib.concatStringsSep "\n" lines
      ) (lib.filterAttrs (_: v: v != {}) attrs) # Filter out sections that are empty attrsets
    );

  # Define the content of qBittorrent.conf based on module options
  qbittorrentConfContent = generateConfigLines {
    BitTorrent = lib.filterAttrs (_: v: v != null) {
      "Session\\BTProtocol" = cfg.bittorrent.protocol;
      "Session\\Port" = cfg.bittorrent.port;
      "Session\\GlobalDLSpeedLimit" = cfg.bittorrent.globalDownloadSpeedLimit;
      "Session\\GlobalUPSpeedLimit" = cfg.bittorrent.globalUploadSpeedLimit;
      "Session\\Interface" = cfg.bittorrent.interface; # User should set this to VPN interface name in namespace
      "Session\\InterfaceName" = cfg.bittorrent.interfaceName; # Usually same as above
      "Session\\Preallocation" = cfg.bittorrent.preallocation;
      "Session\\QueueingSystemEnabled" = cfg.bittorrent.queueingEnabled;
      "Session\\MaxActiveDownloads" = cfg.bittorrent.maxActiveDownloads;
      "Session\\MaxActiveTorrents" = cfg.bittorrent.maxActiveTorrents;
      "Session\\MaxActiveUploads" = cfg.bittorrent.maxActiveUploads;
      "Session\\DefaultSavePath" = cfg.bittorrent.defaultSavePath;
      "Session\\DisableAutoTMMByDefault" = cfg.bittorrent.disableAutoTMMByDefault;
      "Session\\DisableAutoTMMTriggers\\CategorySavePathChanged" = cfg.bittorrent.disableAutoTMMTriggersCategorySavePathChanged;
      "Session\\DisableAutoTMMTriggers\\DefaultSavePathChanged" = cfg.bittorrent.disableAutoTMMTriggersDefaultSavePathChanged;
      "Session\\ExcludedFileNamesEnabled" = cfg.bittorrent.excludedFileNamesEnabled;
      "Session\\ExcludedFileNames" = cfg.bittorrent.excludedFileNames; # This expects a comma-separated string if it's not a list natively in .conf
      "Session\\FinishedTorrentExportDirectory" = cfg.bittorrent.finishedTorrentExportDirectory;
      "Session\\SubcategoriesEnabled" = cfg.bittorrent.subcategoriesEnabled;
      "Session\\TempPath" = cfg.bittorrent.tempPath;
    };
    Core = lib.filterAttrs (_: v: v != null) {
      "AutoDeleteAddedTorrentFile" = cfg.core.autoDeleteTorrentFile;
    };
    Network = lib.filterAttrs (_: v: v != null) {
      "PortForwardingEnabled" = cfg.network.portForwardingEnabled; # Typically false if behind VPN without port forwarding
    };
    Preferences = lib.filterAttrs (_: v: v != null) {
      # Bind WebUI to the veth IP if VPN is enabled and configured, otherwise 0.0.0.0
      "WebUI\\Address" = if cfg.vpn.enable then cfg.vpn.vethVpnIp else "0.0.0.0";
      "WebUI\\LocalHostAuth" = cfg.webUI.localHostAuth;
      "WebUI\\AuthSubnetWhitelist" = cfg.webUI.authSubnetWhitelist; # Comma-separated string
      "WebUI\\AuthSubnetWhitelistEnabled" = cfg.webUI.authSubnetWhitelistEnabled;
      "WebUI\\Username" = cfg.webUI.username;
      "WebUI\\Port" = cfg.webUI.port;
      "WebUI\\Password_PBKDF2" = cfg.webUI.password_PBKDF2;
      "WebUI\\CSRFProtection" = cfg.webUI.csrfProtection;
      "WebUI\\ClickjackingProtection" = cfg.webUI.clickjackingProtection;
    };
  };

  # Create the qBittorrent.conf file in the Nix store
  qbittorrentConfFile = pkgs.writeText "qBittorrent.conf" qbittorrentConfContent;

  # Script to set up network namespace (if managed) and veth pair for WebUI access
  setupNetworkScript = pkgs.writeShellScriptBin "qbittorrent-netns-setup" ''
    set -e # Exit on error
    PATH=${lib.makeBinPath [ pkgs.iproute2 ]}:$PATH

    NS="${cfg.vpn.namespace}"
    VETH_HOST="${cfg.vpn.vethHostName}"
    VETH_VPN="${cfg.vpn.vethVpnName}"
    VETH_HOST_IP="${cfg.vpn.vethHostIp}"
    VETH_VPN_IP="${cfg.vpn.vethVpnIp}"
    VETH_NETMASK="${cfg.vpn.vethNetmask}" # This is just the number, e.g. 24

    echo "Ensuring network namespace $NS and veth pair for qBittorrent WebUI..."
    # Manage namespace lifecycle if configured to do so
    if ! ip netns list | grep -q "^\$NS"; then
      if ${lib.boolToString cfg.vpn.manageNamespaceLifecycle}; then
        echo "Namespace $NS not found. Creating it as manageNamespaceLifecycle is true."
        ip netns add "$NS"
      else
        echo "Error: Network namespace $NS does not exist. Please ensure it's created and managed externally (e.g., by your WireGuard module)."
        exit 1
      fi
    else
      echo "Namespace $NS already exists."
    fi

    echo "Ensuring loopback interface is up in $NS..."
    ip -n "$NS" link set lo up

    # Create veth pair if veth-host doesn't exist
    if ! ip link show "$VETH_HOST" > /dev/null 2>&1; then
      echo "Creating veth pair: $VETH_HOST <-> $VETH_VPN"
      ip link add "$VETH_HOST" type veth peer name "$VETH_VPN"
      echo "Moving $VETH_VPN to namespace $NS"
      ip link set "$VETH_VPN" netns "$NS"

      echo "Configuring IP for $VETH_HOST: '$VETH_HOST_IP/$VETH_NETMASK'"
      ip addr add "$VETH_HOST_IP/$VETH_NETMASK" dev "$VETH_HOST"
      echo "Configuring IP for $VETH_VPN in $NS: $VETH_VPN_IP/$VETH_NETMASK"
      ip -n "$NS" addr add "$VETH_VPN_IP/$VETH_NETMASK" dev "$VETH_VPN"

      echo "Bringing up $VETH_HOST"
      ip link set "$VETH_HOST" up
      echo "Bringing up $VETH_VPN in $NS"
      ip -n "$NS" link set "$VETH_VPN" up
    else
      echo "veth interface $VETH_HOST already exists. Assuming it's configured."
      # Ensure peer is in the right namespace if host exists
      if ! ip -n "$NS" link show "$VETH_VPN" > /dev/null 2>&1; then
        if ip link show "$VETH_VPN" > /dev/null 2>&1; then # Check if it's in host namespace
            echo "Moving existing $VETH_VPN to namespace $NS"
            ip link set "$VETH_VPN" netns "$NS"
            # Re-apply IP and link up just in case
            echo "Re-configuring IP for $VETH_VPN in $NS: $VETH_VPN_IP/$VETH_NETMASK"
            ip -n "$NS" addr add "$VETH_VPN_IP/$VETH_NETMASK$" dev "$VETH_VPN" || true # May fail if already set
            echo "Bringing up $VETH_VPN in $NS"
            ip -n "$NS" link set "$VETH_VPN" up
        else
            echo "Warning: $VETH_HOST exists but $VETH_VPN not found in host or $NS namespace. Manual intervention may be needed."
        fi
      else
         echo "$VETH_VPN already in namespace $NS."
         # Ensure it's up
         ip -n "$NS" link set "$VETH_VPN" up
      fi
       # Ensure host side is up
       ip link set "$VETH_HOST" up
    fi
    echo "Network setup for qBittorrent WebUI complete."
  '';

  # Script to clean up veth pair and optionally network namespace
  cleanupNetworkScript = pkgs.writeShellScriptBin "qbittorrent-netns-cleanup" ''
    set -e
    PATH=${lib.makeBinPath [ pkgs.iproute2 ]}:$PATH

    NS="${cfg.vpn.namespace}"
    VETH_HOST="${cfg.vpn.vethHostName}"

    echo "Cleaning up veth pair for qBittorrent WebUI..."

    if ip link show "$VETH_HOST" > /dev/null 2>&1; then
      echo "Deleting veth interface $VETH_HOST"
      ip link del "$VETH_HOST" || echo "Warning: Failed to delete $VETH_HOST. It might be in use or already gone."
    else
      echo "veth interface $VETH_HOST not found, skipping deletion."
    fi

    if ${lib.boolToString cfg.vpn.manageNamespaceLifecycle}; then
      if ip netns list | grep -q "^\$NS"; then
        echo "Deleting network namespace $NS as manageNamespaceLifecycle is true."
        # Note: Namespace deletion fails if any interface is still attached or processes are running in it.
        ip netns del "$NS" || echo "Warning: Failed to delete namespace $NS. It might be in use or already gone."
      else
        echo "Namespace $NS not found, skipping deletion (manageNamespaceLifecycle is true)."
      fi
    else
      echo "Namespace $NS lifecycle not managed by this module, not deleting it."
    fi

    echo "Network cleanup for qBittorrent complete."
  '';

in
{
  options.services.qbittorrent = {
    enable = lib.mkEnableOption "qBittorrent-nox daemon";

    package = lib.mkPackageOption pkgs "qbittorrent-nox" {
      # Allow choosing between qbittorrent and qbittorrent-nox
      extraDescription = "Typically 'qbittorrent-nox' for headless server.";
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
      description = "The directory where qBittorrent stores its runtime data (e.g., .torrent files, resume data, logs). Not for downloads unless specified in defaultSavePath.";
    };
    configDir = lib.mkOption {
      type = lib.types.path;
      default = "${cfg.dataDir}/config"; # qBittorrent will use this as its --profile path.
      description = "The directory qBittorrent uses as its profile path. The actual qBittorrent.conf will be placed in '{configDir}/qBittorrent/config/qBittorrent.conf'.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Open port in the host's firewall for the qBittorrent WebUI.
        Generally not needed if using the VPN and veth pair setup, as WebUI access
        is intended via the veth pair's host IP (e.g., ${cfg.vpn.vethHostIp}:${toString cfg.webUI.port}).
        Enable this if you want to access the WebUI via the host's main IP address and are NOT using the veth setup for WebUI.
      '';
    };
    webUIPortToOpen = lib.mkOption {
      type = lib.types.port;
      default = cfg.webUI.port;
      description = "Port to open in the firewall if openFirewall is true. This should match WebUI port.";
    };

    # qBittorrent specific settings, mirroring the structure in qBittorrent.conf
    bittorrent = {
      protocol = lib.mkOption { type = lib.types.nullOr (lib.types.enum [ "TCP" "TCP+uTP" ]); default = "TCP"; description = "Torrent transport protocol."; };
      port = lib.mkOption { type = lib.types.nullOr lib.types.port; default = 6881; description = "Incoming connection port for torrent traffic (within the namespace)."; };
      globalDownloadSpeedLimit = lib.mkOption { type = lib.types.nullOr lib.types.int; default = 0; description = "Global download speed limit in KiB/s (0 for unlimited)."; };
      globalUploadSpeedLimit = lib.mkOption { type = lib.types.nullOr lib.types.int; default = 0; description = "Global upload speed limit in KiB/s (0 for unlimited)."; };
      interface = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "Network interface to bind to for torrenting (e.g., 'wg-mullvad' or your VPN interface name inside the namespace). If null, qBittorrent uses the default route in its namespace."; };
      interfaceName = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "Network interface name (usually same as 'interface')."; };
      preallocation = lib.mkOption { type = lib.types.nullOr lib.types.bool; default = false; description = "Preallocate disk space for all files."; };
      queueingEnabled = lib.mkOption { type = lib.types.nullOr lib.types.bool; default = true; description = "Enable torrent queuing."; };
      maxActiveDownloads = lib.mkOption { type = lib.types.nullOr lib.types.int; default = 3; description = "Maximum number of active downloads."; };
      maxActiveTorrents = lib.mkOption { type = lib.types.nullOr lib.types.int; default = 5; description = "Maximum number of active torrents (downloading and seeding)."; };
      maxActiveUploads = lib.mkOption { type = lib.types.nullOr lib.types.int; default = 3; description = "Maximum number of active uploads (seeding)."; };
      defaultSavePath = lib.mkOption { type = lib.types.nullOr lib.types.path; default = "/var/lib/qbittorrent/downloads"; description = "Default path to save downloaded torrents. Ensure qBittorrent user has write access."; };
      disableAutoTMMByDefault = lib.mkOption { type = lib.types.nullOr lib.types.bool; default = false; description = "Disable Automatic Torrent Management by default for new torrents."; };
      disableAutoTMMTriggersCategorySavePathChanged = lib.mkOption { type = lib.types.nullOr lib.types.bool; default = false; description = "Disable Auto TMM when category save path changes."; };
      disableAutoTMMTriggersDefaultSavePathChanged = lib.mkOption { type = lib.types.nullOr lib.types.bool; default = false; description = "Disable Auto TMM when default save path changes."; };
      excludedFileNamesEnabled = lib.mkOption { type = lib.types.nullOr lib.types.bool; default = false; description = "Enable filtering of excluded file names."; };
      excludedFileNames = lib.mkOption { type = lib.types.nullOr (lib.types.listOf lib.types.str); default = null; description = "List of file names/patterns to exclude. Will be comma-separated in config."; };
      finishedTorrentExportDirectory = lib.mkOption { type = lib.types.nullOr lib.types.path; default = null; description = "Directory to export finished torrents to (e.g. for hardlinking)."; };
      subcategoriesEnabled = lib.mkOption { type = lib.types.nullOr lib.types.bool; default = true; description = "Enable subcategories."; };
      tempPath = lib.mkOption { type = lib.types.nullOr lib.types.path; default = "${cfg.bittorrent.defaultSavePath}/.incomplete"; description = "Path for temporary/incomplete files. Ensure qBittorrent user has write access."; };
    };

    core = {
      autoDeleteTorrentFile = lib.mkOption { type = lib.types.nullOr lib.types.bool; default = false; description = "Automatically delete .torrent files after they are added."; };
    };

    network = {
      portForwardingEnabled = lib.mkOption { type = lib.types.nullOr lib.types.bool; default = false; description = "Enable UPnP/NAT-PMP port forwarding (often ineffective/undesirable with VPNs)."; };
    };

    webUI = {
      enable = lib.mkOption { type = lib.types.bool; default = true; description = "Enable the qBittorrent WebUI."; };
      localHostAuth = lib.mkOption { type = lib.types.nullOr lib.types.bool; default = true; description = "Bypass authentication for requests originating from localhost (within the namespace, relevant for veth access)."; };
      authSubnetWhitelist = lib.mkOption { type = lib.types.nullOr (lib.types.listOf lib.types.str); default = null; description = "List of subnets (CIDR notation) to bypass authentication. Will be comma-separated in config."; };
      authSubnetWhitelistEnabled = lib.mkOption { type = lib.types.nullOr lib.types.bool; default = false; description = "Enable subnet whitelist for authentication bypass."; };
      username = lib.mkOption { type = lib.types.nullOr lib.types.str; default = "admin"; description = "WebUI username."; };
      port = lib.mkOption { type = lib.types.nullOr lib.types.port; default = 8080; description = "WebUI port. qBittorrent will listen on this port on the IP specified by WebUI\\Address (e.g., vethVpnIp)."; };
      password_PBKDF2 = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "WebUI password (PBKDF2 hashed). Example: \"@ByteArray(hash_value:salt_value)\". Generate using 'qbittorrent-nox --webui-password-generate <desired_password>' or set a plain text password via WebUI on first run and copy the hash from the generated qBittorrent.conf.";
        example = ''"@ByteArray(ARQCHZ7KMpAt20Py93L/Iw==:MTIzNDU2Nzg5MDEyMzQ1Njc4OTA=)"''; # Example from common defaults
      };
      csrfProtection = lib.mkOption { type = lib.types.nullOr lib.types.bool; default = true; description = "Enable CSRF protection for WebUI."; };
      clickjackingProtection = lib.mkOption { type = lib.types.nullOr lib.types.bool; default = true; description = "Enable Clickjacking protection for WebUI."; };
    };

    # VPN and Network Namespace specific options
    vpn = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true; # Primary goal of this module structure
        description = "Enable running qBittorrent in a dedicated network namespace. This allows isolating its network traffic, typically for a VPN setup. Assumes a VPN client (e.g. WireGuard) is configured to use this namespace.";
      };
      namespace = lib.mkOption {
        type = lib.types.str;
        default = "qbittorrent-vpn";
        description = "Name of the network namespace for qBittorrent. This namespace must exist or be created if 'manageNamespaceLifecycle' is true. Your VPN interface should be assigned to this namespace externally (e.g. via networking.wireguard.interfaces.<name>.interfaceNamespace).";
      };
      manageNamespaceLifecycle = lib.mkOption {
        type = lib.types.bool;
        default = false; # Default to false, assuming VPN module (like WireGuard) manages namespace
        description = "If true, this qBittorrent module will attempt to create the namespace if it doesn't exist and delete it on service stop. Set to false if the namespace is managed by another service (e.g., a WireGuard module as shown in the tutorial).";
      };
      vethHostName = lib.mkOption {
        type = lib.types.str;
        default = "veth-qb-host";
        description = "Name of the veth interface created on the host side to communicate with the qBittorrent WebUI.";
      };
      vethVpnName = lib.mkOption {
        type = lib.types.str;
        default = "veth-qb-vpn";
        description = "Name of the veth interface created on the qBittorrent namespace side for WebUI communication.";
      };
      vethHostIp = lib.mkOption {
        type = lib.types.str;
        default = "10.200.200.1";
        description = "IP address for the host side of the veth pair. Access WebUI via http://<vethHostIp>:<webUIPort>.";
      };
      vethVpnIp = lib.mkOption {
        type = lib.types.str;
        default = "10.200.200.2";
        description = "IP address for the qBittorrent namespace side of the veth pair. qBittorrent WebUI will listen on this IP if VPN mode is enabled.";
      };
      vethNetmask = lib.mkOption {
        type = lib.types.str; # Just the number, e.g. "24"
        default = "24";
        description = "Netmask (CIDR suffix, e.g., 24) for the veth pair subnet.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # User and group setup
    users.users = lib.mkIf (cfg.user == "qbittorrent") { # Only define if using the default name
      qbittorrent = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.dataDir; # qBittorrent may write some files here if not strictly using profile
      };
    };
    users.groups = lib.mkIf (cfg.group == "qbittorrent") { # Only define if using the default name
      qbittorrent = {};
    };

    # Create data and config directories with correct permissions
    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0750 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.configDir}' 0750 ${cfg.user} ${cfg.group} - -"
      # qBittorrent expects this specific subdirectory structure within its profile/config dir
      "d '${cfg.configDir}/qBittorrent' 0750 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.configDir}/qBittorrent/config' 0750 ${cfg.user} ${cfg.group} - -"
      # Note: Download directory permissions (cfg.bittorrent.defaultSavePath, cfg.bittorrent.tempPath)
      # should be managed by the user to ensure the cfg.user has write access.
    ];

    systemd.services.qbittorrent = {
      description = "qBittorrent Daemon";
      after = [ "network.target" "wireguard-wg-vpn.service" ]
        ++ lib.optional cfg.vpn.enable "network-online.target"; # Wait for network, especially if VPN related
      wantedBy = [ "multi-user.target" ];
      requires = [ "wireguard-wg-vpn.service" ];
      # Ensure the service runs after the network namespace and veth pair are set up (if enabled)
      # and after the VPN interface is expected to be in the namespace.
      # This might need manual coordination with the VPN service if manageNamespaceLifecycle is false.
      # E.g., ensure this service starts after your WireGuard service that sets up the namespace.
      # For instance, you could add: `after = [ "systemd-networkd.service" "wg-quick-wg-mullvad.service" ];`
      # if `wg-mullvad` is your WireGuard interface name.

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        # Set umask so files created by qbittorrent (downloads) have reasonable permissions.
        # Example: 002 would give rwxrwxr-x for directories and rw-rw-r-- for files.
        # This is often better handled by qBittorrent's internal settings if available, or user's session umask.
        # UMask = "0002"; # Uncomment and adjust if needed.

        ExecStartPre = [
          # Ensure the full directory structure for qBittorrent.conf exists
          "${pkgs.coreutils}/bin/mkdir -p ${cfg.configDir}/qBittorrent/config"
          # Copy the generated config file to the expected location within the profile directory
          "${pkgs.coreutils}/bin/cp ${qbittorrentConfFile} ${cfg.configDir}/qBittorrent/config/qBittorrent.conf"
          # Ensure correct ownership of the entire config/profile directory
          "${pkgs.coreutils}/bin/chown -R ${cfg.user}:${cfg.group} ${cfg.configDir}"
        ] ++ lib.optional cfg.vpn.enable "${setupNetworkScript}/bin/qbittorrent-netns-setup"; # Setup veth and optionally namespace

        ExecStart = let
            # Base command for qbittorrent, using the specified config directory as its profile
            baseCmd = "${lib.getExe cfg.package} --profile=${cfg.configDir} --no-splash";
            # Add option to disable WebUI if cfg.webUI.enable is false
            webUICmd = if cfg.webUI.enable then "" else " --webui-port=-1";
            fullCmd = baseCmd + webUICmd;
        in # Execute command within the network namespace if VPN mode is enabled
           lib.optionalString cfg.vpn.enable "${pkgs.iproute2}/bin/ip netns exec ${cfg.vpn.namespace} " + fullCmd;

        Restart = "on-failure";
        RestartSec = "10s"; # Give a bit more time for restart

        # If qBittorrent needs to bind to privileged ports (<1024) for its torrenting port (not WebUI)
        # it might need capabilities, but this is rare. Standard ports are >1024.
        # CapabilityBoundingSet = lib.optionalString cfg.vpn.enable "CAP_NET_ADMIN"; # ip netns exec usually handles this
        # AmbientCapabilities = lib.optionalString cfg.vpn.enable "CAP_NET_ADMIN";

        # Script to clean up veth pair and optionally namespace when service stops
        ExecStopPost = lib.optional cfg.vpn.enable "${cleanupNetworkScript}/bin/qbittorrent-netns-cleanup";
      };

    };

    # Firewall rules for WebUI (if explicitly enabled for host's main IP)
    networking.firewall = lib.mkIf (cfg.openFirewall && cfg.webUI.enable) {
      allowedTCPPorts = [ cfg.webUIPortToOpen ];
    };
  };
}