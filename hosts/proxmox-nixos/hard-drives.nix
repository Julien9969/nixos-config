{ config, lib, pkgs, secrets, ... }:
let
  notify-discord = import ../../scripts/notify-discord.nix { inherit pkgs secrets; };
in
{
  # Création des points de montage avec les permissions appropriées
  systemd.tmpfiles.rules = [
    "d /media 0775 root media - -"
    "d /media/DSK 0775 root media - -"
    "d /media/NAS 0775 root media - -"
    "d /media/EXOS 0775 root media - -"
    "d /media/KFC 0775 root media - -"
    "d /media/PFK 0775 root media - -"
  ];

  fileSystems = {
    "/media/PFK" = {
      device = "/dev/disk/by-uuid/21bd99d5-f303-4b50-b8b1-5bcad6cc2ce2";
      fsType = "ext4";
      options = [ "nofail" "noatime" ];
    };

    "/media/EXOS" = {
      device = "/dev/disk/by-uuid/335fff74-08ab-4dad-9cb7-9d719106076c";
      fsType = "ext4";
      options = [ "nofail" "noatime" "errors=remount-ro" ];
    };

    "/media/NAS" = {
      device = "/dev/disk/by-uuid/728adc7c-630e-4ef5-9c77-368d5c500eac";
      fsType = "ext4";
      options = [ "nofail" "noatime" ];
    };

    "/media/DSK" = {
      device = "/dev/disk/by-uuid/a4cac6f4-51c7-4378-a608-c5710e5ae31a";
      fsType = "ext4";
      options = [ "nofail" "noatime" ];
    };

    # "/media/KFC" = {
    #   device = "/dev/disk/by-uuid/50257994-d2c1-4110-bec2-b5ed78b89df3";
    #   fsType = "ext4";
    #   options = [ "nofail" "noatime" ];
    # };
  };

  # Gestion de la mise en veille HDD (hdparm)
  # services.udev.extraRules = 
  #   let
  #     mkRule = as: lib.concatStringsSep ", " as;
  #     mkRules = rs: lib.concatStringsSep "\n" rs;
  #   in mkRules [
  #     (mkRule [
  #       ''ACTION=="add|change"''
  #       ''SUBSYSTEM=="block"''
  #       ''KERNEL=="sd[a-z]"''
  #       ''ATTR{queue/rotational}=="1"''
  #       ''RUN+="${pkgs.hdparm}/bin/hdparm -B 90 -S 41 /dev/%k1"''
  #     ])
  #   ];
}