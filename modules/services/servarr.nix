
{config, pkgs, lib, ...}:
{
  services.sonarr = {
    enable = true;
    openFirewall = true;
    dataDir = "/home/trizotto/config/sonarr";
    user = "trizotto";
    group = "users";
  };
}