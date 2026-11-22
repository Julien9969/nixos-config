{ config, lib, pkgs, ... }:
{
    users.groups.media.gid = 1001;
    systemd.tmpfiles.rules = [ "d /media 0775 root media - -" ];
}