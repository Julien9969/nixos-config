# modules/services/docker.nix
{ config, pkgs, ... }:
{
  services.jellyfin = {
      enable = true;
      openFirewall = true; # TODO disable when using reverse proxy
      user = "jellyfin"; # User that the Jellyfin service will run as
      group = "jellyfin"; # Group for the Jellyfin service

      dataDir = "/var/lib/jellyfin"; # Default directory for media metadata and data
      cacheDir = "/var/cache/jellyfin"; # Cache directory used by Jellyfin
      configDir = "/var/lib/jellyfin/config"; # Directory for Jellyfin configuration
      logDir = "/var/log/jellyfin"; # Directory where logs are stored
      # package = pkgs.jellyfin; # Default Jellyfin package from nixpkgs
  };


  # # 1. enable vaapi on OS-level
  # nixpkgs.config.packageOverrides = pkgs: {
  #   # Only set this if using intel-vaapi-driver
  #   intel-vaapi-driver = pkgs.intel-vaapi-driver.override { enableHybridCodec = true; };
  # };
  # systemd.services.jellyfin.environment.LIBVA_DRIVER_NAME = "iHD"; # Or "i965" if using older driver
  # environment.sessionVariables = { LIBVA_DRIVER_NAME = "iHD"; };      # Same here
  # hardware.graphics = {
  #   enable = true;
  #   extraPackages = with pkgs; [
  #     intel-media-driver # For Broadwell (2014) or newer processors. LIBVA_DRIVER_NAME=iHD
  #     intel-vaapi-driver # For older processors. LIBVA_DRIVER_NAME=i965
  #     libva-vdpau-driver # Previously vaapiVdpau
  #     intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
  #     # OpenCL support for intel CPUs before 12th gen
  #     # see: https://github.com/NixOS/nixpkgs/issues/356535
  #     intel-compute-runtime-legacy1 
  #     vpl-gpu-rt # QSV on 11th gen or newer
  #     intel-media-sdk # QSV up to 11th gen
  #     intel-ocl # OpenCL support
  #   ];
  # };
}
