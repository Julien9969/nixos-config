/services/openssh.nix
{ config, pkgs, ... }:
{
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      # X11Forwarding = true;
      # PasswordAuthentication = false; # disable password login
    };
    openFirewall = true;
  };
}