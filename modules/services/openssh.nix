# modules/services/openssh.nix
{ config, pkgs, ... }:
{
  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      # X11Forwarding = true;
      # PasswordAuthentication = false; # disable password login
    };
    openFirewall = true;
  };
}