{ config, pkgs, lib, secrets, ... }:
let
  mkVirtualHost = (import ../../lib/mk-virtualhost);
in
{
  services.glances = {
    enable = true;
    openFirewall = false;
    # https://glances.readthedocs.io/en/latest/cmds.html
    extraArgs = [
      "--webserver"
    ];
    port = 5678;
  };

  services.nginx.virtualHosts."glances.${secrets.main_domain}" = mkVirtualHost {
    forceSSL    = true;
    useACMEHost = secrets.main_domain;

    locations."/" = {
      proxyPass = "http://localhost:5678";
      proxyWebsockets = true;
    };

    extraConfig = ''
    '';

    blockCommonExploit = true;
    cacheAssets = true;
  };
}
