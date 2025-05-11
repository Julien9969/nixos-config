{ config, pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./hard-drives.nix
    ./nvidia.nix
    ../../modules/common/firewall.nix
    ../../modules/common/users.nix
    ../../modules/common/nix.nix
    ../../modules/sops.nix
    ../../modules/services/bash.nix
    ../../modules/services/docker.nix
    ../../modules/services/openssh.nix
    ../../modules/services/jellyfin.nix
    # ../../modules/services/servarr.nix
    # ../../modules/services/cockpit.nix
    ../../modules/services/reverse-proxy.nix
  ];

  networking.hostName = "trizottoserver";
  
  environment.variables.EDITOR = "micro";
  zramSwap.enable = true;
  powerManagement.cpuFreqGovernor = "performance";

  # needed for vscode-server - allowing foreign binaries to run on NixOS
  programs.nix-ld.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    micro
    git

    # Jellyfin
    jellyfin
    jellyfin-web
    jellyfin-ffmpeg

    # cockpit

    # servarr
    # sonarr
  ];

  system.autoUpgrade = {
    enable = true;
    allowReboot = true; # Optional: reboot if needed
    dates = "Mon 03:00"; # Runs once per week (default Sunday at midnight)
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # Don't sleep on lid close
  services.logind.lidSwitchExternalPower = "ignore";
 
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Paris";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "fr_FR.UTF-8";
    LC_IDENTIFICATION = "fr_FR.UTF-8";
    LC_MEASUREMENT = "fr_FR.UTF-8";
    LC_MONETARY = "fr_FR.UTF-8";
    LC_NAME = "fr_FR.UTF-8";
    LC_NUMERIC = "fr_FR.UTF-8";
    LC_PAPER = "fr_FR.UTF-8";
    LC_TELEPHONE = "fr_FR.UTF-8";
    LC_TIME = "fr_FR.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "fr";
    variant = "azerty";
  };

  # Configure console keymap
  console.keyMap = "fr";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
