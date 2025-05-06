{ config, pkgs, ... }:

{
  home.username = "trizotto";
  home.homeDirectory = "/home/trizotto";

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    neofetch
    # nnn # terminal file manager

    # archives
    zip
    xz
    unzip

    # utils
    # ripgrep # recursively searches directories for a regex pattern
    jq # A lightweight and flexible command-line JSON processor
    # yq-go # yaml processor https://github.com/mikefarah/yq
    # eza # A modern replacement for ‘ls’
    # fzf # A command-line fuzzy finder

    # networking tools
    # mtr # A network diagnostic tool
    # iperf3
    # dnsutils  # `dig` + `nslookup`
    # ldns # replacement of `dig`, it provide the command `drill`
    # aria2 # A lightweight multi-protocol & multi-source command-line download utility
    # socat # replacement of openbsd-netcat
    nmap # A utility for network discovery and security auditing
    # ipcalc  # it is a calculator for the IPv4/v6 addresses

    # misc
    # cowsay
    # file
    which
    tree
    # gnused
    # gnutar
    # gawk
    # zstd
    # gnupg

    # productivity
    # hugo # static site generator
    glow # markdown previewer in terminal

    btop  # replacement of htop/nmon
    iotop # io monitoring
    iftop # network monitoring

    # system call monitoring
    # strace # system call monitoring
    # ltrace # library call monitoring
    # lsof # list open files

    # system tools
    # sysstat
    # lm_sensors # for `sensors` command
    # ethtool
    # pciutils # lspci
    # usbutils # lsusb

    # vscode-fhs	# Allows extensions to be added directly via the code UI
  ];

  # basic configuration of git, please change to your own
  programs.git = {
    enable = true;
    userName = "Trizotto";
    userEmail = "julein.roux404@gmail.com";
    extraConfig = {
      push.autoSetupRemote = true;
      init.defaultBranch = "main";
    };
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;
    # TODO add your custom bashrc here
    
    # currently done manualy
    # bashrcExtra = ''
    #  export PATH="$PATH:$HOME/bin:$HOME/.local/bin"
    # '';

    shellAliases = {
    };
  };

  # This value determines the home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update home Manager without changing this value. See
  # the home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "24.11";

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;
}