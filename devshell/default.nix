{ pkgs }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    git
    vim
  ];

  shellHook = ''
    echo "Welcome to your NixOS devshell 👋"
  '';
}
