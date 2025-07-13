{ config, pkgs, lib, ... }:
{
  users.groups.media = {
    gid = 1001;
  };

  users.users.trizotto = {
    isNormalUser = true;
    description = "Trizotto";
    extraGroups = [ "networkmanager" "wheel" "docker" "media" ];
    packages = with pkgs; [ ];

    # sops-nix will place the authorized_keys file in the home directory at runtime 
    # openssh.authorizedKeys.keyFiles = [
    #   config.sops.secrets."authorized_keys".path
    # ];
  };
  
  security.sudo.extraRules = [
  	{
  		users = [ "trizotto" ];
  		commands = [{
  		  command = "ALL";
  		  options = [ "NOPASSWD" ];
  		}];
  	}
  ];
}
