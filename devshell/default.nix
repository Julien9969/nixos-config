{ pkgs }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    git
    vim
    ssh-to-age
    age
    sops
  ];

  shellHook = ''
    echo "Welcome to your NixOS devshell 👋"
  '';
}
