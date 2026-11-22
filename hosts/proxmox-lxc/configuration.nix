{ config, pkgs, lib, ... }:

{
  imports =
    [
      ./mount.nix
    ];

  # Proxmox reste responsable du nom d'hote, du reseau et du materiel.
  proxmoxLXC = {
    manageNetwork = false;
    manageHostName = false;
    privileged = true;
  };

  networking.hostName = "nixtrizottoserver-lxc";

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      libva-utils
      intel-compute-runtime
      vpl-gpu-rt
      libvpl
    ];
  };

  # Cette option est specifique aux conteneurs non privilegies.
  nix.settings.sandbox = false;
  nixpkgs.config.allowUnfree = true;

  time.timeZone = "Europe/Paris";
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

  console.keyMap = "us-acentos";

  environment.systemPackages = with pkgs; [
    wget
    curl
    git
    micro
    htop
    net-tools
    tree
  ];

  system.activationScripts.diff = {
    supportsDryActivation = true;
    deps = [ ]; 
    text = ''
      export PATH=$PATH:${pkgs.nix}/bin
      if [[ -e /run/current-system ]]; then
        # \e[32m starts green text
        # \e[0m resets the color to default
        echo -e "\e[32m"
        ${pkgs.nvd}/bin/nvd diff /run/current-system "$systemConfig"
        echo -e "\e[0m"
      fi
    '';
  };

  # Les modules communs sont importes par le flake, afin d'appliquer les
  # utilisateurs et les reglages simples sans importer les services applicatifs.
  users.users.trizotto.extraGroups = lib.mkForce [ "wheel" "media" ];

  # services.resolved = {
  #   settings.Resolve = {
  #     Cache = true;
  #     CacheFromLocalhost = true;
  #   };
  # };

  # Migration minimale: aucun service applicatif n'est importe.
  services.fstrim.enable = false;
  # services.resolved.enable = false;
  networking.firewall.enable = false;
  # networking.networkmanager.enable = false;
  # networking.enableIPv6 = false;

  # Elements potentiellement dangereux, volontairement non appliques:
  # - DHCP/adresse statique/gateway: geres par Proxmox;
  # - firewall/TCP/UDP: aucune regle locale;
  # - DNS: /etc/resolv.conf reste controle par Proxmox;
  # - Docker, Nginx, reverse proxy, Tailscale, VPN et WireGuard;
  # - Jellyfin, Immich, Servarr, qBittorrent, Beszel et autres applications;
  # - disques, montages, Udev, GPU, bootloader et pass-through;
  # - X11, bureau graphique, accelerateurs materiels et logiciels specifiques.
  #
  # Aucun import hardware-configuration.nix, hard-drives.nix ou intel.nix
  # n'est present dans cette cible. Ils devront etre revus et reactives
  # manuellement apres validation du LXC.

  system.stateVersion = "26.05";
}
