{ config, lib, pkgs, unstable-pkgs, ... }:
let
  cfg = config.services.seerr;
in {

  options.services.seerr = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = ''
        Enable seerr service.
      '';
    };

    package = lib.mkPackageOption pkgs "seerr" {};

    user = lib.mkOption {
      type = lib.types.str;
      default = "seerr";
      description = "User account under which seerr runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "seerr";
      description = "Group under which seerr runs.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5055;
      description = "seerr Port";
    };

    configDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/seerr";
      description = "seerr data directory";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = "Open firewall for seerr";
    };
  };

  config = lib.mkIf (cfg.enable) {
    systemd.tmpfiles.rules = [
      "d '${cfg.configDir}' 0750 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.seerr = {
      description = "seerr";
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

    users.users.seerr = lib.mkIf (cfg.user == "seerr") {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.configDir;
    };

    users.groups = lib.mkIf (cfg.group == "seerr") {
      seerr = {};
    };
  };
}