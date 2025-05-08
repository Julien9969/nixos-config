# modules/services/bash.nix
{ config, pkgs, ... }:
{
  programs.bash = {

    completion = {
      enable = true;
      package = pkgs.bash-completion;
    };

    enableLsColors = true;

    promptInit = ''
      export PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "
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
}