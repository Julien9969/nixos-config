{ config, lib, pkgs, secrets, unstable-pkgs, ... }:
let
  mkVirtualHost = (import ../../lib/mk-virtualhost);
  cfg = config.services.myServices.beszel;
in {

  options.services.myServices.beszel = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the Beszel monitoring hub + agent";
    };

    enableProxy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable reverse proxy for the Beszel hub web UI";
    };

    enableAgent = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the Beszel agent (reports this host's stats to the hub)";
    };

    enableSmartmon = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable S.M.A.R.T. disk monitoring via smartctl in the agent";
    };
  };

  config = lib.mkMerge [
    # ── beszel hub ──
    (lib.mkIf cfg.enable {
    
      #systemd.tmpfiles.rules = [
      #  "d /var/lib/my-config/beszel-hub 0750 root root - -"
      #];

      systemd.services.beszel-hub.serviceConfig = {
        StateDirectory = lib.mkForce "my-config/beszel-hub";
        RuntimeDirectory = lib.mkForce "my-config/beszel-hub";
        StateDirectoryMode = "0750";
      };

      services.beszel.hub = {
        enable = true;

        # PLACEHOLDER: no option found for `package` override necessity here,
        # but it exists (services.beszel.hub.package) — set if you want to pin
        # to unstable, e.g.:
        package = unstable-pkgs.beszel;

        dataDir = "/var/lib/my-config/beszel-hub";

        # PLACEHOLDER: docs/options don't specify a default host/port explicitly
        # in what you pulled — confirm against `services.beszel.hub.host` /
        # `services.beszel.hub.port` defaults before overriding. Common default
        # is host = "127.0.0.1" (or "0.0.0.0" if you want it reachable without
        # the proxy) and port = 8090. Adjust as needed:
        # host = "127.0.0.1";
        port = 8090;

        # PLACEHOLDER: use this if you need secrets (e.g. SMTP creds, auth
        # tokens) without putting them in the nix store directly.
        # environmentFile = secrets.beszelHubEnvFile;

        # PLACEHOLDER: plain (non-secret) env vars for the hub go here, e.g.
        # environment = {
        #   SOME_HUB_OPTION = "value";
        # };
      };

      # PLACEHOLDER: the jellyfin module used ReadWritePaths on another
      # service (prowlarr) for a shared dir — no equivalent cross-service
      # write requirement is documented for beszel, so omitted. Add if your
      # setup needs it, e.g.:
      # systemd.services.someOtherService.serviceConfig.ReadWritePaths = [ "/var/lib/my-config/beszel" ];
    })

    # ── beszel agent ──
    (lib.mkIf (cfg.enable && cfg.enableAgent) {
      services.beszel.agent = {
        enable = true;

        # PLACEHOLDER: same as hub — pin to unstable if desired:
        # package = unstable-pkgs.beszel-agent;

        # The agent needs to reach the hub; if hub is proxied and not
        # world-reachable, keep this false and let the agent talk to the hub
        # over localhost/LAN as appropriate for your topology.
        openFirewall = false;

        # PLACEHOLDER: KEY is required by the agent (see docs: `KEY="..."`)
        # to authenticate against the hub. No option surfaced for it in your
        # list, meaning it's likely passed via `environment` or
        # `environmentFile`. Recommended: keep it out of the nix store.
        # environmentFile = secrets.beszelAgentEnvFile; # must define KEY=...

        # PLACEHOLDER: extra filesystems to monitor beyond the defaults.
        # Docs mention EXTRA_FILESYSTEMS as an env var for the binary agent;
        # under NixOS this may map to `environment` or a dedicated option
        # (`services.beszel.agent.extraPath` was listed but its exact
        # semantics — single path vs list — weren't in the docs you pasted).
        # Confirm with `nixos-option` / manual before relying on it, e.g.:
        # extraPath = "/mnt/network-share";
        environment = {
           #EXTRA_FILESYSTEMS = "sdb,sdc1,/mnt/network-share";
          KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAC8hfo5s9kYiePCzjcAy/gPT7wJEKabU8LuJPy4IrAV";
          TOKEN="3cc82360-a789-4719-9a6b-115e5934f10b";
          HUB_URL="https://beszel.trizottoserver.freeddns.org";
        };
        # NOTE from docs: avoid RequiresMountsFor for extra filesystems since
        # a failed mount can block the whole service from starting. If you
        # need mount ordering instead of a hard requirement, add an `After=`
        # via serviceConfig, not RequiresMountsFor:
        # systemd.services.beszel-agent.after = [ "mnt-network-share.mount" ];
      };

      # ── S.M.A.R.T. monitoring (optional) ──
      # PLACEHOLDER: smartmon.deviceAllow presumably maps to systemd
      # DeviceAllow= entries for the specific disks you want smartctl to
      # read. Fill in your actual device nodes here:
      services.beszel.agent.smartmon = lib.mkIf cfg.enableSmartmon {
        enable = true;

        # package = unstable-pkgs.smartmontools; # PLACEHOLDER if you need a pin

        # PLACEHOLDER: replace with your real disk device paths, e.g.:
        # deviceAllow = [ "/dev/sda" "/dev/nvme0" ];
        deviceAllow = [ ];
      };

      # PLACEHOLDER: docs recommend granting CAP_SYS_RAWIO / CAP_SYS_ADMIN
      # via ambient capabilities rather than running the agent as root, if
      # the module doesn't already do this for you when smartmon.enable is
      # set. Check generated unit with `systemctl cat beszel-agent` first —
      # only add this manually if it's missing:
      # systemd.services.beszel-agent.serviceConfig = {
      #   AmbientCapabilities = [ "CAP_SYS_RAWIO" "CAP_SYS_ADMIN" ];
      #   CapabilityBoundingSet = [ "CAP_SYS_RAWIO" "CAP_SYS_ADMIN" ];
      # };
    })

    # ── reverse-proxy nginx for the hub UI ──
    (lib.mkIf (cfg.enable && cfg.enableProxy) {
      services.nginx.virtualHosts."beszel.${secrets.main_domain}" = mkVirtualHost {
        forceSSL    = true;
        useACMEHost = secrets.main_domain;

        locations."/" = {
          # PLACEHOLDER: match this to services.beszel.hub.port above
          proxyPass = "http://localhost:8090";
          proxyWebsockets = true;
        };

        extraConfig = ''
          proxy_buffering off;
          sendfile on;
        '';

        blockCommonExploit = true;
        cacheAssets = true;
      };
    })
  ];
}