# /etc/nixos/tailscale.nix
{ config, pkgs, lib, unstable-pkgs, ... }:
let
  enabled = config.services.myServices.tailscale.enable or false;
in
{
    options.services.myServices.tailscale = {
        enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable the Tailscale service";
        };
    };

    config = lib.mkIf enabled {
        services.tailscale = {
            enable = true;
            package = unstable-pkgs.tailscale;

            openFirewall = true;
            useRoutingFeatures = "server"; # "client", "server", "both", or "none"

            # Auth key file so the node authenticates automatically at boot.
            # Generate a reusable, pre-authorized key from:
            # https://login.tailscale.com/admin/settings/keys
            authKeyFile = config.sops.secrets.tailscale_key.path;

            #authKeyParameters = {
                # ephemeral = false;      # don't remove the node when it disconnects
                # preauthorized = true;   # skip manual approval in admin console
            #};

            # Flags passed to `tailscale up` on every start — this is what gives you "auto up"
            extraUpFlags = [
            "--reset"
            #"--accept-routes"
            #"--accept-dns=true"
            # "--advertise-exit-node"        # uncomment if this machine should be an exit node
            # "--advertise-routes=192.168.1.0/24"  # uncomment for subnet routing
            ];
        };

        # Make sure the tailscale daemon starts on boot and stays up
        systemd.services.tailscaled.wantedBy = [ "multi-user.target" ];
    };
}