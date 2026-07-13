{ config, lib, pkgs, secrets, ... }:
let
  notify-discord = import ../../scripts/notify-discord.nix { inherit pkgs secrets; };
in
{
  # boot.supportedFilesystems = [ "ntfs" ];
  systemd.tmpfiles.rules = [
    "d /media 0775 root media - -"
    "d /media/DSK 0775 root media - -"
    "d /media/NAS 0775 root media - -"
    "d /media/EXOS 0775 root media - -"
  ];
  fileSystems."/media/DSK" = {
    device = "/dev/disk/by-uuid/a4cac6f4-51c7-4378-a608-c5710e5ae31a";
    fsType = "ext4";
    options = [
      "nofail"
    ];
  };
  fileSystems."/media/NAS" = {
    device = "/dev/disk/by-uuid/728adc7c-630e-4ef5-9c77-368d5c500eac";
    fsType = "ext4";
    options = [
      "nofail"
    ];
  };
  # SET DISK QUIRKS
  # boot.kernelParams = [ "usb-storage.quirks=7825:a2a4:u" ];
  # boot.extraModprobeConfig = ''
  #   options usb-storage quirks=7825:a2a4:u,174c:1153:u
  # '';

  fileSystems."/media/EXOS" = {
    device = "/dev/disk/by-uuid/335fff74-08ab-4dad-9cb7-9d719106076c";
    fsType = "ext4";
    options = [
      "nofail"            # don't block boot if absent
      "noauto"            # don't mount at boot, let automount handle it
      "noatime"           # no access time writes over USB
      "lazytime"          # defer timestamp writes
      "user_xattr"
      "errors=remount-ro" # on EXT4 error, go read-only instead of panicking
      "x-systemd.automount"
      "x-systemd.idle-timeout=60"        # release device after 60s idle
      "x-systemd.mount-timeout=30s"
      "x-systemd.device-timeout=30s"
    ];
  };

  services.udev.extraRules = 
    let
      mkRule = as: lib.concatStringsSep ", " as;
      mkRules = rs: lib.concatStringsSep "\n" rs;
    in mkRules ([( mkRule [
      ''ACTION=="add|change"''
      ''SUBSYSTEM=="block"''
      ''KERNEL=="sd[a-z]"''
      ''ATTR{queue/rotational}=="1"''
      ''RUN+="${pkgs.hdparm}/bin/hdparm -B 90 -S 41 /dev/%k1"''
    ])]); 

  systemd.services."exos-mount-watchdog" = {
    description = "Keep /media/EXOS mounted";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    script = ''
      set -eu
      # if ! ${pkgs.util-linux}/bin/mountpoint -q /media/EXOS; then
      # if ! timeout 5 ${pkgs.coreutils}/bin/stat /media/EXOS >/dev/null 2>&1; then
      
      if ! timeout 5 ls -U /media/EXOS >/dev/null || ! ${pkgs.util-linux}/bin/mountpoint -q /media/EXOS; then
        echo "/media/EXOS is not mounted, stopping dependents..."
        mount_start=$SECONDS
        
        # Stop qbittorrent (adjust the service name if yours differs, e.g., qbittorrent-nox.service)
        # ${pkgs.systemd}/bin/systemctl stop qbittorrent.service || true

        echo "Lazily unmounting /media/EXOS..."
        ${pkgs.util-linux}/bin/umount -l /media/EXOS || true

        sleep 5  # Give the system a moment to process the unmount
        
        #echo "Attempting to mount /media/EXOS with systemd..."
        #${pkgs.systemd}/bin/systemctl start media-EXOS.mount
        
        echo "Checking for disk availability by UUID..."
        uuidPath="/dev/disk/by-uuid/335fff74-08ab-4dad-9cb7-9d719106076c"
        found=1
        for i in $(seq 1 10); do
          if [ -e "$uuidPath" ]; then
            found=0
            break
          fi
          echo "Disk not present yet, retrying ($i/10)..."
          sleep 2
        done

        if [ "$found" -ne 0 ]; then
          echo "Disk not found after polling; skipping mount."
        else
          echo "Attempting to mount /media/EXOS by UUID..."
          ${pkgs.util-linux}/bin/mount -U 335fff74-08ab-4dad-9cb7-9d719106076c /media/EXOS || true
        fi

        mount_elapsed=$((SECONDS - mount_start))

        ${pkgs.util-linux}/bin/lsblk

        # Verify the mount succeeded before starting qbittorrent again
        if ${pkgs.util-linux}/bin/mountpoint -q /media/EXOS; then
          echo "Mount restored. Starting dependents..."
          # ${pkgs.systemd}/bin/systemctl restart qbittorrent.service || true
        else
          echo "Failed to restore mount. Leaving qbittorrent stopped to prevent root fs writes."
        fi

#        mount_elapsed=$((SECONDS - mount_start))
        ${notify-discord.script}/bin/notify-discord exos-remount "$mount_elapsed" #>/dev/null 2>&1 || true
      fi
    '';
  };

  systemd.timers."exos-mount-watchdog" = {
    description = "Check /media/EXOS every 60 seconds";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "120s";
      OnUnitActiveSec = "60s";
      Unit = "exos-mount-watchdog.service";
      Persistent = true;
    };
  };
}
