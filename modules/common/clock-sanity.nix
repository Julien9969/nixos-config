{ config, lib, pkgs, ... }:

# On power failure the hardware clock can reset to 2019, which breaks
# DNSSEC validation and therefore all DNS / NTP sync.
# This service enforces a known-good minimum date so that TLS/DNSSEC
# certificates remain valid and NTP can then correct to real time.

let
  # Bump this value whenever you rebuild so the floor stays recent.
  minimumDate = "2026-04-15 00:00:00";
in
{
  systemd.services."clock-sanity" = {
    description = "Ensure system clock is not stuck in the past";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      min_epoch=$(${pkgs.coreutils}/bin/date -d "${minimumDate}" +%s)
      cur_epoch=$(${pkgs.coreutils}/bin/date +%s)
      if [ "$cur_epoch" -lt "$min_epoch" ]; then
        echo "System clock ($cur_epoch) is before minimum ($min_epoch), advancing to ${minimumDate}"
        ${pkgs.coreutils}/bin/date -s "${minimumDate}"
      else
        echo "System clock is OK ($(date))"
      fi
    '';
  };

  systemd.timers."clock-sanity" = {
    description = "Run clock-sanity every hour";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "1h";
      Persistent = true;
    };
  };

  # Make sure NTP is enabled so the real time is set after the floor is applied
  services.timesyncd.enable = true;
}
