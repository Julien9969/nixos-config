# modules/common/openssh.nix
{ config, pkgs, ... }:
{
  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";
}