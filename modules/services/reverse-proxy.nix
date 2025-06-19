# module/services/reverse-proxy/default.nix
{ config, pkgs, lib, secrets, ... }:
let
  mainDomain = secrets.main_domain;
  acmeEmail = secrets.acme_email;

  mkVirtualHost = (import ../../lib/mk-virtualhost);
in {

  security.acme = {
    acceptTerms = true;
    defaults.email = acmeEmail;
    certs."${mainDomain}" = {
      domain = mainDomain;
      extraDomainNames = [ "*.${mainDomain}" ];
      dnsProvider = "dynu";
      environmentFile = config.sops.secrets.dynu_api_key.path;
    };
  };

  users.users.nginx.extraGroups = [ "acme" ];

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedTlsSettings = true; 

    clientMaxBodySize = "30M"; 
    
    # Custom Nginx configuration
    # httpConfig = ''''; 
    # appendConfig = ''''; 

    #! Check avec RPI 
    # streamConfig = '''';

    appendHttpConfig = ''
      proxy_cache_path /var/cache/nginx/public levels=1:2 keys_zone=public-cache:10m max_size=100m inactive=60m use_temp_path=off;
      
      map $scheme $hsts_header {
        https "max-age=31536000; includeSubdomains; preload";
      }

      add_header Strict-Transport-Security $hsts_header;

      # Enable CSP for your services.
      # add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;

      # Minimize information leaked to other domains
      add_header 'Referrer-Policy' 'origin-when-cross-origin';

      # Disable embedding as a frame
      add_header X-Frame-Options DENY;

      # Prevent injection of code in other mime types (XSS Attacks)
      add_header X-Content-Type-Options nosniff;

      add_header X-Cache-Status $upstream_cache_status always;
    '';

    virtualHosts = {
      "192.168.1.150" = {
        forceSSL = false;
        locations."/" = {
          proxyPass = "http://10.200.200.1:8080";
          proxyWebsockets = false;
          # extraConfig = '''';
        };
      };

      "qbit.${mainDomain}" = mkVirtualHost {
        forceSSL = true;
        useACMEHost = mainDomain;
        locations."/" = {
          proxyPass = "http://10.200.200.1:8080";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Referer $scheme://$host$request_uri;
            proxy_cookie_path  / "/; Secure";
          '';
        };
        blockCommonExploit = true;
        cacheAssets = true;
      };
    };
  };

  # 404 for unrecognized hosts
  services.nginx.virtualHosts."*.${mainDomain}" = {
    serverName = "*.${mainDomain}"; # Catch-all server name
    useACMEHost = mainDomain;
    forceSSL = true;
    locations."/" = {
      return = 404;
    };
  };
}
