# modules/common/users.nix
{ config, pkgs, ... }:

{
  users.users.trizotto = {
    isNormalUser = true;
    description = "Trizotto";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    packages = with pkgs; [ ];
    openssh.authorizedKeys.keys = [
       #"ssh-ed25519 <some-public-key> blabla@blabla"
    ];
  };

  #services.openssh = {
  #  enable = true;
  #  settings = {
  #    X11Forwarding = true;
  #    PermitRootLogin = "no"; # disable root login
  #    PasswordAuthentication = false; # disable password login
  #  };
  #  openFirewall = true;
  #};
}
