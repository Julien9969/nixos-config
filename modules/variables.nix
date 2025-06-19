# /etc/nixos/variables.nix
{ secrets }:
{
  GIT_USERNAME = "Trizotto";
  GIT_EMAIL = secrets.git_email;
}