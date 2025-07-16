{ config, lib, pkgs, ... }:
let
  cfg = config.services.jellyseerr;
in {

  options.services.jellyseerr = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = ''
        Enable jellyseerr service.
      '';
    };

    package = lib.mkPackageOption pkgs "jellyseerr" {};

    user = lib.mkOption {
      type = lib.types.str;
      default = "jellyseerr";
      description = "User account under which jellyseerr runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "jellyseerr";
      description = "Group under which jellyseerr runs.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5055;
      description = "jellyseerr Port";
    };

    configDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/jellyseerr";
      description = "jellyseerr data directory";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = "Open firewall for jellyseerr";
    };
  };

  config = lib.mkIf (cfg.enable) {
    systemd.tmpfiles.rules = [
      "d '${cfg.configDir}' 0750 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.jellyseerr = {
      description = "jellyseerr";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      environment = {
        PORT = toString cfg.port;
        CONFIG_DIRECTORY = cfg.configDir;
      };

      serviceConfig = {
        Type = "simple";
        ReadWritePaths = [ "${cfg.configDir}" ];
        User = cfg.user;
        Group = cfg.group;
        ExecStart = lib.getExe cfg.package;
        Restart = "on-failure";
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };

    users.users.jellyseerr = lib.mkIf (cfg.user == "jellyseerr") {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.configDir;
    };

    users.groups = lib.mkIf (cfg.group == "jellyseerr") {
      jellyseerr = {};
    };
  };
}