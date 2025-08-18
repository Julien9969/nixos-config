{ config, pkgs, lib, ... }:
let
  cfg = config.services.wireguardVpn;
in
{
  options.services.wireguardVpn = {
    enable = lib.mkEnableOption "WireGuard VPN tunnel for network namespaces";

    name = lib.mkOption {
      type = lib.types.str;
      apply = name: 
        assert lib.asserts.assertMsg (name != "") "Name cannot be empty";
        assert lib.asserts.assertMsg (lib.match "^[a-z]+$" name != null) "Name must contain only lowercase letters a-z";
        assert lib.asserts.assertMsg (builtins.stringLength name <= 7) "Name must be at most 7 characters long (interface in linux is up to 15 and our prefix is 8)";
        name;
      description = "Unique name for this WireGuard VPN instance/network namespace.";
    };

    interfaceName = lib.mkOption {
      type = lib.types.str;
      default = "wg-${cfg.name}";
      description = "Name of the WireGuard interface.";
    };

    privateKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to a file that contains the WireGuard private key.";
    };

    address = lib.mkOption {
      type = lib.types.str;
      description = "IP address/subnet to assign to the VPN interface.";
      example = "10.2.0.2/32";
    };

    dns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "DNS server to assign to the VPN interface.";
      example = [ "10.2.0.1" ];
    };

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 51820;
      description = "Listening port for the WireGuard interface.";
    };

    peers = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          publicKey = lib.mkOption {
            type = lib.types.str;
            description = "Public key of the peer.";
          };

          endpoint = lib.mkOption {
            type = lib.types.str;
            description = "Endpoint of the peer.";
            example = "x.x.x.x:xxxx";
          };

          allowedIPs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "0.0.0.0/0" ];
            description = "List of IP addresses/subnets to allow through the VPN tunnel.";
          };

          persistentKeepalive = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "Persistent keepalive interval in seconds.";
          };
        };
      });
      default = [];
      description = "List of WireGuard peer configurations.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the WireGuard listen port in the firewall.";
    };

    exposed = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          namespace = lib.mkOption {
            type = lib.types.str;
            description = "Network namespace used by this WireGuard instance.";
          };
          interface = lib.mkOption {
            type = lib.types.str;
            description = "Name of the WireGuard interface.";
          };
          address = lib.mkOption {
            type = lib.types.str;
            description = "IP address assigned to the WireGuard interface.";
          };
        };
      });
      default = {};
      description = "Exposed metadata of configured WireGuard instances.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.wireguard.interfaces.${cfg.interfaceName} = {
      ips = [ cfg.address ];
      privateKeyFile = cfg.privateKeyFile;
      listenPort = cfg.listenPort;
      interfaceNamespace = cfg.name;

      preSetup = ''
        # Clean up existing namespace/veth if they exist
        if ip netns list | grep -q ${cfg.name}; then
          ip netns del ${cfg.name} || true
          ip link del vt-host-${cfg.name} || true
        fi

        # Create a new network namespace
        ip netns add ${cfg.name}
        ip -n ${cfg.name} link set lo up

        # Create a veth pair for host and namespace communication
        ip link add vt-host-${cfg.name} type veth peer name vt-${cfg.name}
        ip link set vt-${cfg.name} netns ${cfg.name}

        #! TODO this will not work if address not different (mutiple wg instances)
        # Assign IP addresses to the veth interfaces
        ip addr add 10.200.200.101/24 dev vt-host-${cfg.name}
        ip -n ${cfg.name} addr add 10.200.200.1/24 dev vt-${cfg.name}

        # Bring up the veth interfaces
        ip link set vt-host-${cfg.name} up
        ip -n ${cfg.name} link set vt-${cfg.name} up

        ip netns exec ${cfg.name} ${pkgs.iptables}/bin/iptables -I INPUT -i vt-${cfg.name} -p tcp --dport 8085 -j ACCEPT
        ip netns exec ${cfg.name} ${pkgs.iptables}/bin/iptables -I OUTPUT -o vt-${cfg.name} -j ACCEPT
      '';

      postSetup = ''
        # Force the WireGuard interface to be the default route for the namespace
        ip -n ${cfg.name} route add default dev ${cfg.interfaceName}       
      '';

      postShutdown = ''
        # Delete the veth pair and the namespace on shutdown
        ip link del vt-host-${cfg.name} || true
        ip netns del ${cfg.name} || true
        # ip netns exec ${cfg.name} ${pkgs.iptables}/bin/iptables -D INPUT -i ${cfg.interfaceName} -j ACCEPT || true
        # TODO le reste ?
      '';

      peers = lib.map (peer: {
        publicKey = peer.publicKey;
        endpoint = peer.endpoint;
        allowedIPs = peer.allowedIPs;
        inherit (peer) persistentKeepalive;
      }) cfg.peers;
    };

    environment.etc."netns/${cfg.name}/resolv.conf".text = lib.concatStringsSep "\n" (map (ip: "nameserver ${ip}") cfg.dns);

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedUDPPorts = [ cfg.listenPort ];
    };

    #! Expose the network namespace, interface name, and address
    services.wireguardVpn.exposed.${cfg.name} = {
      namespace = cfg.name;
      interface = cfg.interfaceName;
      address = cfg.address;
    };
  };
}