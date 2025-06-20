# minecraft‑neoforge.nix
{ lib, pkgs, config, ... }:

let
  # ⇩ Pick the Minecraft / NeoForge versions wanted
  # https://projects.neoforged.net/neoforged/neoforge
  mcVersion = "1.21.1";
  neoforgeVersion = "21.1.180";

  serverDir = "/var/lib/minecraft-neoforge";

  neoforgeUrl      =
    "https://maven.neoforged.net/releases/net/neoforged/neoforge/"
    + "${neoforgeVersion}/"
    + "neoforge-${neoforgeVersion}-installer.jar";

  # Get with nix-prefetch-url --type sha256 "${neoforgeUrl}" (add sha256- prefix)
  neoforgeSha256 = "sha256-maLlNmoCmNYdRPfuASlkkYd6WD8Z0evu7nDNQj8/cXU="; #lib.fakeSha256;
  neoforgeModpackUrl = "https://mediafilez.forgecdn.net/files/6642/446/BMC5_Server_Pack_v32.zip";

  unzipModpack = "${pkgs.bash}/bin/bash ${pkgs.writeShellScript "unzipModpack" ''
    if [ ! -f ${serverDir}/modpack.zip ]; then
      echo "Downloading NeoForge modpack..."
      mkdir -p ${serverDir}
      ${pkgs.curl}/bin/curl -L -o ${serverDir}/modpack.zip ${neoforgeModpackUrl}
      echo "Extracting NeoForge modpack..."
      ${pkgs.unzip}/bin/unzip -qq -o ${serverDir}/modpack.zip -d ${serverDir}
    else
      echo "NeoForge modpack already exists, skipping download."
    fi

    # "${pkgs.screen}/bin/screen -S minecraft -X quit || true"

    # Ensure the eula.txt file is present
    echo "eula=true" > ${serverDir}/eula.txt
    ${pkgs.openjdk24_headless}/bin/java -jar /etc/minecraft-neoforge/neoforge.jar nogui > "${serverDir}/install.log" 2>&1
  ''}";

  gracefulStopScript = pkgs.writeShellScript "minecraft-graceful-stop" ''
    ${pkgs.screen}/bin/screen -S minecraft -X stuff "say SERVER SHUTTING DOWN IN 10 SECONDS. SAVING ALL MAPS...\r"
    sleep 10
    ${pkgs.screen}/bin/screen -S minecraft -X stuff "save-all\r"
    ${pkgs.screen}/bin/screen -S minecraft -X stuff "stop\r"
    sleep 12
    ${pkgs.screen}/bin/screen -S minecraft -X quit || true
    echo "Minecraft server stopped gracefully."
  '';
in 
{
  options.services.minecraft-neoforge.enable =
    lib.mkEnableOption "NeoForge Minecraft server";

  config = lib.mkIf config.services.minecraft-neoforge.enable {
    environment.systemPackages = [ pkgs.openjdk24_headless pkgs.screen ];

    users.groups.minecraft = {};
    users.users.minecraft = {
      isSystemUser = true;
      group = "minecraft";
      home = serverDir;
    };

    environment.etc."minecraft-neoforge/neoforge.jar".source =
      pkgs.fetchurl { url = neoforgeUrl; hash = neoforgeSha256; };

    systemd.tmpfiles.rules = [
      "d ${serverDir}          0750 minecraft minecraft -"
      "d ${serverDir}/mods     0750 minecraft minecraft -"
      "f ${serverDir}/eula.txt 0640 minecraft minecraft - eula=true"
    ];

    systemd.services.minecraft-neoforge = {
      description = "NeoForge Minecraft Server";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        User = "minecraft";
        Group = "minecraft";
        WorkingDirectory = serverDir;
        ExecStartPre = [ "${unzipModpack}" ];
        ExecStart = "${pkgs.screen}/bin/screen -DmS minecraft ${pkgs.openjdk24_headless}/bin/java -Xms4G -Xmx8G -XX:+UseG1GC -jar ${serverDir}/server.jar nogui";
        ExecStop = [
          "${gracefulStopScript}"
        ];
        Restart = "on-failure";
        UMask = "0027";
        AmbientCapabilities = "";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = "read-only";
        ProtectSystem = "full";
      };
      wantedBy = [ "multi-user.target" ];
    };

    networking.firewall.allowedTCPPorts = [ 25565 ];
  };
}
