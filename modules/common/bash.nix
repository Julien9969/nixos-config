# modules/common/bash.nix
{ config, pkgs, ... }:
{
  programs.bash = {

    completion = {
      enable = true;
      package = pkgs.bash-completion;
    };

    enableLsColors = true;

    promptInit = ''
      # username@hostname:~/bin$
      # export PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "
      
      if [ "$EUID" -eq 0 ]; then
        COLOR="01;31"  # Red for root
      else
        COLOR="01;32"  # Green for user
      fi
      
      # trizotto@trizottoserver:/etc/nixos (main)$
      PS1='\[\e['"$COLOR"'m\]\u@\h\[\e[00m\]:\[\e[01;34m\]\w\[\e[38;5;215m\]$(__git_ps1 " (%s)")\[\e[00m\]\$ '
    '';

    undistractMe = {
      enable = true;
      playSound = true;
      timeout = 60;
    };

    # Optional: Define a custom LS_COLORS file (uncomment if used)
    # lsColorsFile = ./my-ls-colors;
    
    # Not realy good when ssh
    # blesh.enable = true;
    # vteIntegration = true;
  };
  
  # For git infos in bash prompt (doesn't work, so do it manualy)
  # programs.git.prompt.enable = true;
  environment.interactiveShellInit = ''
    source ${config.programs.git.package}/share/git/contrib/completion/git-prompt.sh
  '';
}
