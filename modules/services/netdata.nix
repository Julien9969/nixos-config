{ config, pkgs, lib, secrets, ... }:
let 
  mkVirtualHost = (import ../../lib/mk-virtualhost);
in
{
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [ "netdata" "nvidia-x11" ];

  services.netdata = {
    enable = true;

    package = pkgs.netdata.override {
      withCloudUi = true;
    };
    # configDir = "/var/lib/my-config/netdata";
    extraNdsudoPackages = [
      pkgs.smartmontools
    ];

    config.global = {
      "memory mode" = "ram";
      "debug log" = "none";
      "access log" = "none";
      "error log" = "syslog";
    };

    configDir."python.d.conf" = pkgs.writeText "python.d.conf" ''
      nvidia_smi: yes
    '';
  };

  networking.firewall.allowedTCPPorts = [ 19999 ];

  systemd.services.netdata.path = [ pkgs.linuxPackages.nvidia_x11 ];

  services.nginx.virtualHosts."netdata.${secrets.main_domain}" = 
    (mkVirtualHost {
    forceSSL    = true;
    useACMEHost = secrets.main_domain;

    locations."/" = {
      proxyPass = "http://localhost:19999";
      proxyWebsockets = true;
    };

    extraConfig = '''';

    blockCommonExploit = true;
    cacheAssets = true;
  });
}
