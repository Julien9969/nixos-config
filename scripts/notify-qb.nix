{ pkgs, secrets }:
{
    script = pkgs.writeShellScriptBin "notify-qb" '' 
        #!/usr/bin/env bash

        discord_url="${secrets.qb_notif_webhook}"

        octets_to_gio() {
            bytes=$1
            gigabytes=$(( bytes / (1024 * 1024 * 1024) ))
            remaining=$(( bytes % (1024 * 1024 * 1024) ))
            gigabytes_decimal=$(( remaining * 100 / (1024 * 1024 * 1024) ))
            echo "$gigabytes.$gigabytes_decimal"
        }

        add_download() {
        cat <<EOF
            {
                "content": "",
                "avatar_url": "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/qbittorrent.png",
                "username": "Qbittorrent",
                "embeds": [
                    {
                        "author": {
                            "name": "qBittorent",
                            "url": "https://qbittorrent.${secrets.main_domain}"
                        },
                        "title": "Nouveau téléchargement",
                        "description": "> $2",
                        "fields": [
                            {
                                "name": "Catégorie",
                                "value": "$3"
                            },
                            {
                                "name": "Emplacement",
                                "value": "\`$4\`"
                            },
                            {
                                "name": "Tracker",
                                "value": "$6"
                            }
                        ],
                        "thumbnail": {
                            "url": "https://upload.wikimedia.org/wikipedia/commons/6/66/New_qBittorrent_Logo.svg"
                        },
                        "color": "16753920",
                        "footer": {
                            "text": "",
                            "icon_url": "https://github.com/google/material-design-icons/blob/master/png/alert/add_alert/materialicons/48dp/2x/baseline_add_alert_black_48dp.png"
                        },
                        "timestamp": "$current_date_time"
                    }
                ]
            }
        EOF
        }

        download_done() {
        cat <<EOF
        {
            "content": "",
            "avatar_url": "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/qbittorrent.png",
            "username": "Qbittorrent",
            "embeds": [
                {
                "author": {
                    "name": "qBittorent",
                    "url": "https://qbittorrent.${secrets.main_domain}"
                },
                "title": "Fin de téléchargement",
                "description": "> $2",
                "fields": [
                    {
                        "name": "Catégorie",
                        "value": "$3"
                    },
                    {
                        "name": "Emplacement",
                        "value": "\`$4\`"
                    },
                    {
                        "name": "nombre de fichiers et poids",
                        "value": "$5 fichiers - $(octets_to_gio $6) Gio"
                    }
                    ],
                "thumbnail": {
                "url": "https://qbittorrent.${secrets.main_domain}"
                },
                "color": "65280",
                "footer": {
                    "text": "",
                    "icon_url": "https://github.com/google/material-design-icons/blob/master/png/alert/add_alert/materialicons/48dp/2x/baseline_add_alert_black_48dp.png"
                },
                "timestamp": "$current_date_time"
            }]
        }
        EOF
        }


        embed() {
            case $1 in
                add)
                    # echo "add"
                    add_download "$1" "$2" "$3" "$4" "$5" "$6" 
                    ;;
                done)
                    # echo "done"
                    download_done "$1" "$2" "$3" "$4" "$5" $6
                    ;;
                test)
                    # echo "test"
                    generate_post_data "$1"
                    ;;
                *)
                    echo octets_to_gio $6
                    exit 1
                    ;;
            esac
        }

        # Define a function to display help information
        display_help() {
            echo "Usage: $0 [options] [arg1] [arg2]"
            echo "Options:"
            echo "  -h          Display this help message"
            echo "Arguments:"
            echo "  arg1        Type d\'embed (add_download (add), download_done (done), refresh_container(ref))"
            echo "In case of add_download and download_done"
            echo "  arg2        Nom du torrent %N"
            echo "  arg3        Catégorie %L"
            echo "  arg4        Chemin vers le contenu %R"
            echo "  arg5        Nombre de fichiers %C"
            echo "  arg6        Taille du torrent (en octets) %Z"
        }

        # Check if the first argument is -h
        if [[ "$1" == "-h" ]]; then
            display_help
            exit 0
        fi

        current_date_time=$(date +"%Y-%m-%d %H:%M:%S")
        # POST request to Discord Webhook
        ${pkgs.curl}/bin/curl -H "Content-Type: application/json" -X POST -d "$(embed "$@")" $discord_url

    '';
}