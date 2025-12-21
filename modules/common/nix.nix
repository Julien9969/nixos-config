# NixOS common configuration
{ config, pkgs, ... }:
{
  # Autormove nix stuff after sometimes
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  system.autoUpgrade = {
    enable = true;
    allowReboot = true; # Reboot if needed
    dates = "Mon 05:00"; # Runs once per week (default Sunday at midnight)
  };
  
  powerManagement.cpuFreqGovernor = "performance";
  
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=360
  '';

  # Don't sleep on lid close
  services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";

  environment.variables.EDITOR = "micro";
  zramSwap.enable = true;

  nix.package = pkgs.nixVersions.stable;
  
  # needed for vscode-server - allowing foreign binaries to run on NixOS
  programs.nix-ld.enable = true;

  # Enable flakes and experimental Nix features globally
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  # Allow unfree packages globally
  nixpkgs.config.allowUnfree = true;
}
