{ config, pkgs, inputs, ... }:
{
    nixpkgs.overlays = with pkgs; [
      (final: prev: {
        jellyfin-web = prev.jellyfin-web.overrideAttrs (finalAttrs: previousAttrs: {
          installPhase = ''
            runHook preInstall

            # Inject the Editor's Choice script before </body>
            sed -i 's#</body>#<script plugin=\"EditorsChoice\" defer=\"defer\" version=\"1.0.0.0\" src=\"/EditorsChoice/script\"></script></body>#' dist/index.html

            # Inject Intro skipper script before </head>
            sed -i "s#</head>#<script src=\"configurationpage?name=skip-intro-button.js\"></script></head>#" dist/index.html

            mkdir -p $out/share
            cp -a dist $out/share/jellyfin-web

            runHook postInstall
          '';
        });
      })
    ];
}