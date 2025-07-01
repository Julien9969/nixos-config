{ config, lib, pkgs, ... }:
let
  cfg = config.services.prowlarr;
  servarr-utils = import ./settings-options.nix { inherit lib pkgs; };
in {
  options.services.prowlarr = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = ''
        Enable Prowlarr service.
      '';
    };

    package = lib.mkPackageOption pkgs "prowlarr" {};

    user = lib.mkOption {
      type = lib.types.str;
      default = "prowlarr";
      description = "User account under which prowlarr runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "prowlarr";
      description = "Group under which prowlarr runs.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9696;
      description = "Prowlarr Port";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/prowlarr";
      description = "Prowlarr data directory";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = "Open firewall for Prowlarr";
    };

    environmentFiles = servarr-utils.mkServarrEnvironmentFiles "prowlarr";

    settings = servarr-utils.mkServarrSettingsOptions "prowlarr" 9696;
  };

  config = lib.mkIf (cfg.enable) {
    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0700 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.prowlarr = {
      description = "prowlarr";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      environment = servarr-utils.mkServarrSettingsEnvVars "PROWLARR" cfg.settings;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${lib.getExe cfg.package} -nobrowser -data=${cfg.dataDir}";
        Restart = "on-failure";
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };

    users.users = lib.mkIf (cfg.user == "prowlarr") {
      prowlarr = {
        group = cfg.group;
        home = cfg.dataDir;
        uid = config.ids.uids.prowlarr;
      };
    };

    users.groups = lib.mkIf (cfg.group == "prowlarr") {
      prowlarr.gid = config.ids.gids.prowlarr;
    };
  };
}