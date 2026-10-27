{ config, lib, pkgs, secrets, ... }:

# Place next to server.py, e.g. modules/services/licence-server/default.nix
# (rename this file to default.nix) and import it from your configuration.
#
#   services.licence-server.enable = true;
#
# First start generates the signing key; print the PUBLIC key for your client with:
#   sudo licence-admin init
# Then manage licenses with:
#   sudo licence-admin create --product mysoft --owner alice --max-machines 2
#   sudo licence-admin list
#   sudo licence-admin revoke 1

let
  cfg = config.services.myServices.licence-server;
  mkVirtualHost = import ../../../lib/mk-virtualhost;
  py = pkgs.python3.withPackages (ps: [ ps.cryptography ]);
  server = ./server.py;
  dataDir = "/var/lib/licserver";

  env = {
    LICENSE_DATA_DIR = dataDir;
    LICENSE_HOST = cfg.host;
    LICENSE_PORT = toString cfg.port;
    LICENSE_GRACE_DAYS = toString cfg.graceDays;
    LICENSE_UNREACHABLE_GRACE_HOURS = toString cfg.unreachableGraceHours;
    LICENSE_TRUST_PROXY = if cfg.trustProxy then "1" else "0";
  };

  # Runs server.py admin commands as the service user with the same environment.
  admin = pkgs.writeShellScriptBin "licence-admin" ''
    exec /run/wrappers/bin/sudo -u licserver env \
      ${lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "${k}=${lib.escapeShellArg v}") env)} \
      ${py}/bin/python ${server} "$@"
  '';
  
in
{
  options.services.myServices.licence-server = {
    enable = lib.mkEnableOption "the self-hosted licence server";

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address on which the licence server listens.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8787;
      description = "Port on which the licence server listens.";
    };

    graceDays = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 0;
      description = "Offline grace in days (0 = unlimited).";
    };
    unreachableGraceHours = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 0;
      description = "Grace when internet works but this server is unreachable (0 = unlimited).";
    };

    trustProxy = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Trust X-Forwarded-For headers from a reverse proxy.";
    };

    enableProxy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose the licence server through the HTTPS reverse proxy.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.licserver = {};
    users.users.licserver = {
      isSystemUser = true;
      group = "licserver";
      home = "/var/lib/licserver";
      description = "Licence server";
    };

    environment.systemPackages = [ admin ];

    systemd.services.licence-server = {
      description = "Self-hosted licence server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = env;

      serviceConfig = {
        Type = "simple";
        User = "licserver";
        Group = "licserver";
        WorkingDirectory = "/var/lib/licserver";
        ExecStartPre = "${py}/bin/python ${server} init";
        ExecStart = "${py}/bin/python ${server} serve";
        Restart = "on-failure";
        RestartSec = 3;

        StateDirectory = "licserver";
        StateDirectoryMode = "0700";
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
        RestrictNamespaces = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        SystemCallFilter = [ "@system-service" ];
        CapabilityBoundingSet = "";
        ReadWritePaths = [ "/var/lib/licserver" ];
      };
    };

    services.nginx.virtualHosts."lic.${secrets.main_domain}" =
      lib.mkIf cfg.enableProxy (mkVirtualHost {
        forceSSL = true;
        useACMEHost = secrets.main_domain;

        locations."/" = {
          proxyPass = "http://${cfg.host}:${toString cfg.port}";
          proxyWebsockets = false;
        };

        blockCommonExploit = true;
        cacheAssets = false;
      });
  };
}
