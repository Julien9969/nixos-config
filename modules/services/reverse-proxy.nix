{ config, pkgs, lib, ... }:

let
  mainDomain = "192.168.1.150";
  acmeEmail = "local-test@example.com";

  defaultForceSSL = false; # TODO (change) Disable forcing SSL for local HTTP testing
  defaultEnableACME = false; # Disable ACME for local testing
  defaultProxyWebsockets = false;
  defaultExtraProxyConfig = "";

  mkProxy = { backendUrl, 
    proxyWebsockets ? defaultProxyWebsockets,
    forceSSL ? defaultForceSSL, 
    enableACME ? defaultEnableACME, 
    extraProxyConfig ? defaultExtraProxyConfig }:
  {
    forceSSL = forceSSL;
    enableACME = enableACME;
    locations."/" = {
      proxyPass = backendUrl;
      proxyWebsockets = proxyWebsockets;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        ${extraProxyConfig}
      '';
    };
  };

in {

  # --- ACME Configuration (Disabled for local) ---
  security.acme = {
    acceptTerms = true; # Required by the module, but won't be used
    defaults.email = acmeEmail;
    # This effectively disables ACME attempts:
    # server = ""; # Setting an invalid server or ensuring enableACME is false per vhost
  };

  # --- Nginx Service ---
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;

    # Explicitly false if not dealing with SSL at all (local testing)
    recommendedTlsSettings = false; 
    
    # Custom Nginx configuration
    # httpConfig = ''''; 
    # appendConfig = ''''; 
    # appendHttpConfig = ''
    #  # Add HSTS header with preloading to HTTPS requests.
    #  # Adding this header to HTTP requests is discouraged
    #  map $scheme $hsts_header {
    #      https   "max-age=31536000; includeSubdomains; preload";
    #  }
    #  add_header Strict-Transport-Security $hsts_header;

    #  # Enable CSP for your services.
    #  #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;

    #  # Minimize information leaked to other domains
    #  add_header 'Referrer-Policy' 'origin-when-cross-origin';

    #  # Disable embedding as a frame
    #  add_header X-Frame-Options DENY;

    #  # Prevent injection of code in other mime types (XSS Attacks)
    #  add_header X-Content-Type-Options nosniff;
    # '';


    virtualHosts = {
      "jellyfin.${mainDomain}" = mkProxy {
        backendUrl = "http://localhost:8096";
        proxyWebsockets = true;
      };

      "${mainDomain}" = mkProxy {
        backendUrl = "http://10.200.200.1:8080";
        proxyWebsockets = false;
      };
      
      # some testing services (python3 -m http.server 8082)
      # "app2.${mainDomain}" = mkProxy {
      #   backendUrl = "http://localhost:8081";
      # };

      # "app.${mainDomain}" = mkProxy {
      #   backendUrl = "http://localhost:8082";
      # };

      # Add more services here as needed:
      # "myservice.${mainDomain}" = mkProxy {
      #   backendUrl = "http://localhost:8000";
      # };
    };
  };

  # services.nginx.virtualHosts."192.168.1.150".locations."/app/" = {
  #   proxyPass = "http://localhost:8082/";
  #   extraConfig = ''
  #     proxy_set_header Host $host;
  #     proxy_set_header X-Real-IP $remote_addr;
  #     proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  #     proxy_set_header X-Forwarded-Proto $scheme;
  #     proxy_http_version 1.1;
  #     rewrite ^/app(/.*)$ $1 break;
  #   '';
  # };

  # 404 for unrecognized hosts
  services.nginx.virtualHosts."*.${mainDomain}" = {
    serverName = "*.localhost"; # Catch-all server name
    locations."/" = {
      return = 404;
    };
  };
}
