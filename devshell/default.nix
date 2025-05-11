{ pkgs }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    git
    vim
    ssh-to-age
    age
    sops
    home-manager
    python314
  ];

  shellHook = ''
    echo "Welcome to your NixOS devshell 👋"
  '';
}
