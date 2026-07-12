{ config, lib, pkgs, secrets, unstable-pkgs, ... }:
let
  mkVirtualHost = (import ../../lib/mk-virtualhost);
  cfg = config.services.myServices.corsica;
in {

  options.services.myServices.corsica = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the Corsica service";
    };

    enableProxy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable reverse proxy for Corsica";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      systemd.services.corsica = {
        description = "Corsica Bash Script Service";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.bash}/bin/bash -c 'cd /home/trizotto/cms && ${pkgs.nix}/bin/nix-shell shell.nix --run \"pnpm i && pnpm start\"'";
          Restart = "always";
        };
        environment = {
          NIX_PATH = "nixpkgs=flake:nixpkgs:/nix/var/nix/profiles/per-user/root/channels";
        };
      };
    })

    # ── reverse‑proxy nginx ──
    (lib.mkIf (cfg.enable && cfg.enableProxy) {
      services.nginx.virtualHosts."corsica.${secrets.main_domain}" = mkVirtualHost {
        forceSSL    = true;
        useACMEHost = secrets.main_domain;

        locations."/" = {
          proxyPass = "http://localhost:3000"; # Change this to whatever service you want to proxy
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
