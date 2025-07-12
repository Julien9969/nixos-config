{ config, lib, pkgs, ... }:
{
  # boot.supportedFilesystems = [ "ntfs" ];
  
  systemd.tmpfiles.settings.root."/media".z = { # z fix the perms event if folder exist (d not)
    user = "root";
    group = "media";
    mode = "0775"; 
  };

  fileSystems."/media/DSK" = {
    device = "/dev/disk/by-uuid/E26E78BA6E7888D5";
    fsType = "ext4";
    options = [
      "nofail"
    ];
  };

  systemd.tmpfiles.settings.root."/media/DSK".z = {
    user = "root";
    group = "media";
    mode = "0775"; 
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
