# lib/mkVirtualHost.nix
{ locations, 
  useACMEHost, 
  forceSSL ? true, 
  extraConfig ? "", 
  blockCommonExploit ? false, 
  cacheAssets ? false }:
{
  inherit locations forceSSL useACMEHost;
  extraConfig = ''
    ${if blockCommonExploit then "include ${./block-exploits.conf};" else ""}
    ${if cacheAssets then "set $proxyPass ${locations."/".proxyPass};\ninclude ${./cache-asset.conf};" else ""}
    ${extraConfig}
  '';
}