{ config, pkgs, ... }:
{
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = config.users.users.trizotto.home + "/.config/sops/age/keys.txt";
    # age.sshKeyPaths = ["~/.ssh/id_ed25519"];
    secrets = {
      "authorized_keys" = {
        path = "${config.users.users.trizotto.home}/.ssh/authorized_keys"; 
        owner = config.users.users.trizotto.name;                      
        group = config.users.users.trizotto.group;                     
        mode = "0600";
      };
      "username" = {};
      "wg_private_key" = {};
      "dynu_api_key" = {};
      "restic_passwd" = {};
      # "acme_email" = {};
    };
  };
}