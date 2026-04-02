{ config, lib, pkgs, ... }:

# On power failure the hardware clock can reset to 2019, which breaks
# DNSSEC validation and therefore all DNS / NTP sync.
# This service runs very early at boot and bumps the clock to at least
# a known-good minimum date so that TLS/DNSSEC certificates are valid
# and NTP can then correct it to the real time.

let
  # Bump this value whenever you rebuild so the floor stays recent.
  minimumDate = "2026-02-20 00:00:00";
in
{
  systemd.services."clock-sanity" = {
    description = "Ensure system clock is not stuck in the past";
    wantedBy = [ "sysinit.target" ];
    before = [
      "systemd-resolved.service"
      "systemd-timesyncd.service"
      "network-pre.target"
    ];
    after = [ "systemd-modules-load.service" ];
    unitConfig = {
      DefaultDependencies = false;
    };
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

  # Make sure NTP is enabled so the real time is set after the floor is applied
  services.timesyncd.enable = true;
}
