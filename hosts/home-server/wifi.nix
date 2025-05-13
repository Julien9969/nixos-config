{ config, pkgs, ... }:
let
  ssidPath = config.sops.secrets.wifi_ssid.path;
  passwdPath = config.sops.secrets.wifi_passwd.path;
in {

  networking.networkmanager.enable = true;
  
  systemd.services.connectToWifi = {
    description = "Connect to Wi-Fi network via nmcli";
    after = [ "network.target" ];
    path = [ pkgs.networkmanager ];

    # Script that connects to Wi-Fi with nmcli
    serviceConfig.ExecStart = pkgs.writeShellScript "connect-wifi" ''
        SSID=$(cat ${ssidPath})
        PASSWD=$(cat ${passwdPath})
        nmcli device wifi connect "$SSID" password "$PASSWD"
    '';
    wantedBy = [ "multi-user.target" ];
  };
}
