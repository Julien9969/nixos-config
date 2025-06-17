{ config, pkgs, lib, ... }:

let
  mainDomain = "";
  acmeEmail = "";
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

    streamConfig = ''
    '';

    appendHttpConfig = ''
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

      "qbit.${mainDomain}" = {
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

        extraConfig = ''
          include ${./block-exploits.conf};
          # include ${./cache-asset.conf};
        '';
      };

      "jellyfin.${mainDomain}" = {
        forceSSL = true;
        useACMEHost = mainDomain;
        locations."/" = {
          proxyPass = "http://localhost:8096";
          proxyWebsockets = true;
          # extraConfig = ''
          #   proxy_cookie_path  / "/; Secure";
          # '';
        };

        locations."/socket" = {
          proxyPass = "http://localhost:8096";
          proxyWebsockets = true;
        };

        extraConfig = ''
          proxy_buffering off;
          sendfile on;

          include ${./block-exploits.conf};
          # include ${./cache-asset.conf};
        '';
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
