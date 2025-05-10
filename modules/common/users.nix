# modules/common/users.nix
{ config, pkgs, lib, ... }:

{
  users.users.trizotto = {
    isNormalUser = true;
    description = "Trizotto";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    packages = with pkgs; [ ];

    # sops-nix will place the authorized_keys file in the home directory at runtime 
    # openssh.authorizedKeys.keyFiles = [
    #   config.sops.secrets."authorized_keys".path
    # ];
  };
}
