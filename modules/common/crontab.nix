{ config, lib, pkgs, secrets, ... }:
let
  notify-discord = import ../../scripts/notify-discord.nix { inherit secrets pkgs; };
  qbittorrent-cron = import ../../scripts/qbittorrent-cron.nix { inherit config secrets pkgs; };
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
      OnCalendar = "Mon..Sun *-*-01,03,05,07,09,11,13,15,17,19,21,23,25,27,29,31 06:00";  # Every 2 days at 6am
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

  #### Sonarr healthcheck ####
  # systemd.timers."sonarr-healthcheck" = {
  #   wantedBy = [ "timers.target" ];
  #   timerConfig = {
  #     OnCalendar = "hourly";
  #     Persistent = true;
  #     Unit = "sonarr-healthcheck.service";
  #   };
  # };

  # systemd.services."sonarr-healthcheck" = {
  #   script = ''
  #     set -eu
  #     HTTP_CODE=$(${pkgs.curl}/bin/curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://localhost:8989/ping || true)
  #     if [ "$HTTP_CODE" != "200" ]; then
  #       echo "Sonarr healthcheck failed (HTTP $HTTP_CODE), restarting..."
  #       systemctl restart sonarr.service
  #       ${notify-discord.script}/bin/notify-discord sonarr-restart
  #     else
  #       echo "Sonarr is healthy (HTTP $HTTP_CODE)"
  #     fi
  #   '';
  #   serviceConfig = {
  #     Type = "oneshot";
  #     User = "root";
  #   };
  # };
  ###################

  # #### Stop qbitorrent at night ####
  # resume all qBittorrent torrents at 23:00
  systemd.timers."resume-qbittorrent-night" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 23:00";  # Every day at 23:00
      Persistent = true;
      Unit = "resume-qbittorrent-night.service";
    };
  };

  systemd.services."resume-qbittorrent-night" = {
    script = ''
      set -eu
      ${qbittorrent-cron.scripts.resume}/bin/resume-torrents
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };

  # Pause all qBittorrent torrents at 07:00
  systemd.timers."pause-qbittorrent-morning" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 07:00";  # Every day at 07:00
      Persistent = true;
      Unit = "pause-qbittorrent-morning.service";
    };
  };

  systemd.services."pause-qbittorrent-morning" = {
    script = ''
      set -eu
      ${qbittorrent-cron.scripts.pause}/bin/pause-torrents
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };
}
