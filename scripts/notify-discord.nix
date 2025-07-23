{ pkgs, secrets }:
{
    script = pkgs.writeShellScriptBin "notify-discord" '' 
        #!/usr/bin/env bash

        discord_url="${secrets.static_notif_webhook}"

        json() {
        cat <<EOF
        {
            "content": "",
            "avatar_url": "$1",
            "username": "$2",
            "embeds": [
                {
                "author": {
                    "name": "$2",
                    "url": "$6"
                },
                "color": "$5",
                "title": "$3",
                "description": "$4",
                "footer": {
                    "text": "$8",
                    "icon_url": "$9"
                },
                "thumbnail": {
                    "url": "$7"
                },
                "url": "$6",
                "timestamp": "$(date +"%Y-%m-%d %H:%M:%S")"
            }]
        }
        EOF
        }

        embed() {
            case $1 in
                reboot)
                    avatar_url="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons@master/png/nixos.png"
                    username="NixOS trizottoserver"
                    title="Redémarage terminé"
                    description="> $(date +"%Y-%m-%d")\n> $(date +"%H:%M:%S")"
                    color="65280"
                    url="https://dash.${secrets.main_domain}"
                    thumbnail=""
                    footer_text=""
                    footer_image=""
                    sleep 20
                    echo "$(json "$avatar_url" "$username" "$title" "$description" "$color" "$url" "$thumbnail" "$footer_text" "$footer_image")"
                    ;;
                services-restart)
                    avatar_url="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons@master/png/nixos.png"
                    username="Jellyfin & Qbittorrent"
                    title="Redémarage de Jellyfin et Qbittorrent"
                    description="> $(date +"%Y-%m-%d")\n> $(date +"%H:%M:%S")"
                    color="65280"
                    url="https://jellyfin.${secrets.main_domain}"
                    thumbnail="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons@master/png/jellyfin.png"
                    footer_text=""
                    footer_image="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons@master/png/qbittorrent.png"
                    echo "$(json "$avatar_url" "$username" "$title" "$description" "$color" "$url" "$thumbnail" "$footer_text" "$footer_image")"
                    ;;
                backup-server)
                    avatar_url="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons@master/png/nixos.png"
                    username="Server Backup"
                    title="Sauvegarde du serveur"
                    description="\`\`\`scp -P 52222 -r trizotto@${secrets.ssh_host}:/media/DSK/backups/ <out-dir>\`\`\`\n> $(date +"%Y-%m-%d")\n> $(date +"%H:%M:%S")"
                    color="15105570"
                    url="https://filebrowser.${secrets.main_domain}/files/DSK/backups/"
                    thumbnail="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons@master/png/restic.png"
                    footer_text=""
                    footer_image=""
                    echo "$(json "$avatar_url" "$username" "$title" "$description" "$color" "$url" "$thumbnail" "$footer_text" "$footer_image")"
                    ;;
                *)
                    exit 1
                    ;;
            esac

        }

        display_help() {
            echo "Usage: $0 [options] [name of notification]"
            echo "Options:"
            echo "  -h          Display this help message"
            echo "Arguments:"
            echo "  reboot      show reboot done message"
        }

        if [[ "$1" == "-h" ]]; then
            display_help
            exit 0
        fi
        export TZ="Europe/Paris"
        current_date_time=$(date +"%Y-%m-%d %H:%M:%S%:z")

        echo "$(embed "$@")"
        ${pkgs.curl}/bin/curl -H "Content-Type: application/json" -X POST -d "$(embed "$@")" $discord_url
    '';
}