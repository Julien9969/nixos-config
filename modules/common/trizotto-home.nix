{ config, pkgs, vars, ... }:
{
  home.username = "trizotto";
  home.homeDirectory = "/home/trizotto";

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    neofetch
    # nnn # terminal file manager
	  hdparm

    # ffmpeg
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
    restic
    # networking tools
    # mtr # A network diagnostic tool
    # iperf3
    dnsutils  # `dig` + `nslookup`
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
    # iotop # io monitoring
    # iftop # network monitoring

    # system call monitoring
    # strace # system call monitoring
    # ltrace # library call monitoring
    # lsof # list open files

    # system tools
    # sysstat
    lm_sensors # for `sensors` command
    # ethtool
    # pciutils # lspci
    # usbutils # lsusb
    unzip
    # vscode-fhs	# Allows extensions to be added directly via the code UI
  ];

  # basic configuration of git, please change to your own
  programs.git = {
    enable = true;
    userName = vars.GIT_USERNAME;
    userEmail = vars.GIT_EMAIL;
    extraConfig = {
      push.autoSetupRemote = true;
      init.defaultBranch = "main";
      pull.rebase = true;
    };

    aliases = {
      co = "checkout";
      br = "branch";
      ci = "commit";
      st = "status";
      lg = "log --oneline --graph --decorate --all";
      ac = "!git add . && git commit -m";
    };
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;
    historyIgnore = [ "ls" ];
    historyControl = [ "ignoredups" "ignorespace" ];
    shellAliases = {
      sops-edit = "nix-shell -p sops --command 'sops secrets/secrets.yaml'";
      ll = "ls -alF";
      la = "ls -A";
      l = "ls -CF";
      clean-nix = ''
        home-manager expire-generations 0 && \
        sudo nix-collect-garbage -d && \
        nix-collect-garbage -d && \
        sudo nix store optimise
      '';
      devshell = "cd /etc/nixos &&  nix develop";
      dir-size = "du -h --max-depth=1 | sort -hr";
      ccd = "cd /etc/nixos";
      exos = "cd /media/EXOS";
      dsk = "cd /media/DSK";
      nas = "cd /media/NAS";
    };
    
    initExtra = ''
      neofetch
      echo "Welcome, $USER! Today is $(date +'%A, %B %d, %Y')."
    '';

    sessionVariables = { 
      GIT_PS1_SHOWDIRTYSTATE=1;
      GIT_PS1_SHOWSTASHSTATE=1;
      GIT_PS1_SHOWUNTRACKEDFILES=1;
      GIT_PS1_SHOWUPSTREAM="auto";
    };
    # bashrcExtra = '''';
    # initExtra = "";
    # logoutExtra = "";
    # profileExtra = "";
    # bashrcExtra = '''';
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
