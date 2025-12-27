{ config, lib, pkgs, secrets, unstable-pkgs, ... }:
let
    mkVirtualHost = (import ../../lib/mk-virtualhost);
    cfg = config.services.myServices.paperless;
in
{
    options.services.myServices.paperless = {
        enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable Paperless-NGX service";
        };

        enableProxy = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable reverse proxy for Paperless-NGX";
        };

        enableTika = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable Tika and Gotenberg for Office document parsing";
        };
    };

    config = lib.mkIf cfg.enable {
        services.paperless = {
            enable = true;
            package = unstable-pkgs.paperless-ngx;

            dataDir = "/var/lib/my-config/paperless";
            database.createLocally = true;
            port = 28981;
                        
            configureTika = cfg.enableTika;

            settings = {
                PAPERLESS_OCR_LANGUAGE = "eng+fra";
                PAPERLESS_ADMIN_USER = "Trizotto";
                PAPERLESS_URL="https://paperless.${secrets.main_domain}";
                PAPERLESS_SECRET_KEY = "45b39ce9a440b8bbe651e4074b23bac5w87853cd0c102fe1c038fe947ce8e7bb";#secrets.paperless_secret_key;

                PAPERLESS_FILENAME_FORMAT="{{ created_year }}/{{ document_type }}/{{ title }}";

                PAPERLESS_EMAIL_HOST="smtp.gmail.com";
                PAPERLESS_EMAIL_PORT=587;
                PAPERLESS_EMAIL_HOST_USER=secrets.paperless_email_user;
                PAPERLESS_EMAIL_HOST_PASSWORD=secrets.ggapp_pwd_paperless;
                PAPERLESS_EMAIL_FROM=secrets.my_name;
                PAPERLESS_EMAIL_USE_TLS=true;
                
                PAPERLESS_TIKA_ENABLED = cfg.enableTika;
                PAPERLESS_TIKA_ENDPOINT = lib.mkIf cfg.enableTika "http://localhost:9998";
                PAPERLESS_TIKA_GOTENBERG_ENDPOINT = lib.mkIf cfg.enableTika "http://localhost:3081";
            };

            passwordFile = config.sops.secrets.paperless_admin_password.path;
        };

        services.gotenberg = lib.mkIf cfg.enableTika {
            package = unstable-pkgs.gotenberg;
            enable = true;
            port = 3081;
            timeout = "45s";
            chromium.autoStart = false;
            libreoffice.autoStart = false;
            chromium.disableJavascript = true;
        };

        services.tika = lib.mkIf cfg.enableTika {
            enable = true;
            port = 9998;
            listenAddress = "127.0.0.1";
        };

        services.nginx.virtualHosts."paperless.${secrets.main_domain}" = 
            lib.mkIf cfg.enableProxy (mkVirtualHost {
            forceSSL = true;
            useACMEHost = secrets.main_domain;

            locations."/" = {
                proxyPass = "http://${config.services.paperless.address}:${toString config.services.paperless.port}";
                proxyWebsockets = true;
                extraConfig = ''
                    client_max_body_size 100M;
                '';
            };

            locations."/ws" = {
                proxyPass = "http://${config.services.paperless.address}:${toString config.services.paperless.port}";
                proxyWebsockets = true;
            };

            extraConfig = '''';

            blockCommonExploit = true;
            cacheAssets = true;
        });
    };
}
