{ config, pkgs, ... }:

{
  imports =
    [
      ../../modules/services/qbittorent.nix # Path to your new module
    ];

  # ... other configurations ...

  # services.qbittorrent = {
  #   enable = true;
  #   user = "root"; # Or keep default "qbittorrent"
  #   group = "root"; # Or keep default "qbittorrent"

  #   # Ensure this user/group has write access to download/temp paths
  #   dataDir = "/var/lib/qbittorrent-data"; # Persistent state for qBittorrent
  #   configDir = "/var/lib/qbittorrent-data/config"; # Profile directory

  #   bittorrent = {
  #     defaultSavePath = "/media/HDD/torrents/downloading";
  #     tempPath = "/media/HDD/storage/torrents/incomplete";
  #     globalDownloadSpeedLimit = 10000; # 10 MiB/s in KiB
  #     globalUploadSpeedLimit = 5000;   # 5 MiB/s in KiB
  #     # Set this to your VPN interface name *inside* the namespace
  #     interface = "wg-vpn"; # Example: if your WireGuard interface is named wg-vpn
  #     interfaceName = "wg-vpn";
  #   };

  #   webUI = {
  #     enable = true;
  #     port = 8080;
  #     username = "Trizotto";
  #     # Generate this with: qbittorrent-nox --webui-password-generate yoursecurepassword
  #     # password_PBKDF2 = "@ByteArray(GENERATED_HASH_HERE)";
  #   };

  #   vpn = {
  #     enable = true;
  #     namespace = "vpn-ns"; # Same namespace your VPN (e.g. WireGuard) uses
  #     # manageNamespaceLifecycle = false; # If your VPN module creates/deletes the namespace
  #     vethHostIp = "10.100.1.1"; # Access WebUI at http://10.100.1.1:8080
  #     vethVpnIp = "10.100.1.2";   # qBittorrent listens on this IP inside the namespace
  #     vethNetmask = "24";
  #   };
  # };

  # Example WireGuard setup that uses the same namespace
  # This assumes you have a wireguard.nix or similar
  networking.wireguard.interfaces.wg-vpn = {
    # ... your WireGuard private key, peer public key, endpoint ...
    ips = [ "10.2.0.2/32" ]; # Example VPN IP
    privateKeyFile = config.sops.secrets.wg_private_key.path;
    # privateKey = "";

    # CRITICAL: Assign WireGuard interface to the namespace
    interfaceNamespace = "vpn-ns"; # Must match services.qbittorrent.vpn.namespace

    # WireGuard module might handle namespace creation/deletion
    # If so, services.qbittorrent.vpn.manageNamespaceLifecycle should be false.
    # The tutorial's example had preSetup/postShutdown for namespace and veth.
    # If WireGuard handles namespace creation, its preSetup could be:
    preSetup = ''
      # Creates a new network namespace
      ip netns add vpn-ns || true
      # Brings loopback interface for internal networking in ns
      ip -n vpn-ns link set lo up

      # Create a veth pair to link the namespaces
      # ip link add veth-host type veth peer name veth-vpn
      # ip link set veth-vpn netns wg-qbittorrent
      # ip addr add 10.200.200.1/24 dev veth-host
      # ip netns exec wg-qbittorrent ip addr add 10.200.200.2/24 dev veth-vpn
      # ip link set veth-host up
      # ip netns exec wg-qbittorrent ip link set veth-vpn up
      # ip netns exec wg-qbittorrent ip route add default via 10.200.200.1
    '';

    postShutdown = ''
      ip netns del vpn-ns || true
    '';

    peers = [
      # For a client configuration, one peer entry for the server will suffice.
      {
        # Public key of the server (not a file path).
        publicKey = "DznTG0WjFUlvggmQ9FsoUvbrU6D9zz1YgdRImKR/+18=";

        # Forward all the traffic via VPN.
        allowedIPs = [ "0.0.0.0/0" ];
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