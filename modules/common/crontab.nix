{ config, lib, pkgs, secrets, ... }:
let
  notify-discord = import ../../scripts/notify-discord.nix { inherit secrets pkgs; };
in
{
  #### On reboot ####
  systemd.timers."notify-on-boot" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";         # Delay after boot
      Unit = "boot-notify.service";
    };
  };

  systemd.services."boot-notify" = {
    script = ''
      set -eu
      ${notify-discord.script}/bin/notify-discord reboot
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };
  ###################

  #### Jellyfin & Qbittorrent restart ####
  systemd.timers."jellyfin-qbit-every-2-days" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Mon *-*-* 00:00/48";  # Every 2 days at midnight
      Persistent = true; 
      Unit = "restart-jellyfin-qbit.service";
    };
  };

  systemd.services."restart-jellyfin-qbit" = {
    script = ''
      set -eu
      systemctl restart jellyfin.service qbittorrent.service
      ${notify-discord.script}/bin/notify-discord services-restart
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };
  ###################

  #### Auto reboot ####
  systemd.timers."scheduled-reboot" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Thu 04:00";
      Persistent = true;
      Unit = "scheduled-reboot.service";
    };
  };

  systemd.services."scheduled-reboot" = {
    script = ''
      set -eu
      /run/current-system/sw/bin/systemctl reboot
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };
  ###################
}
