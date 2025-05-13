{ config, lib, pkgs, ... }:
{
  boot.supportedFilesystems = [ "ntfs" ];

  fileSystems."/media/HDD" =
  { device = "/dev/disk/by-uuid/E26E78BA6E7888D5";
    fsType = "ntfs-3g";
    options = [
      "uid=1000"    # main user id
      "gid=${toString config.users.groups.media.gid}"  # group = media
      "umask=002"
      "dmask=002"   # Directories = 775
      "fmask=113"   # Files = 664
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
}
