{ config, pkgs, ... }:
{
  fileSystems."/media/HDD" =
    { device = "/dev/disk/by-uuid/E26E78BA6E7888D5";
      fsType = "ntfs3";
      options = [
          "umask=0000"        # Allows read, write, and execute for all users
          "uid=0"             # root ownership, but rwx for all users
          "gid=0"             # group ownership, but rwx for all users
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
