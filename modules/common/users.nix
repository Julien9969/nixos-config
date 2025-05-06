# modules/common/users.nix
{ config, pkgs, ... }:

{
  users.users.trizotto = {
    isNormalUser = true;
    description = "Trizotto";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    packages = with pkgs; [ ];
  };
}
