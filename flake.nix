{
  description = "Trizottoserver NixOS config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";  
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager"; # /release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    nix-private = {
      url = "git+ssh://git@github.com/Julien9969/nix-private.git";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, home-manager, sops-nix, nix-private, ... }: 
    let
      secrets = import "${inputs.nix-private}/secrets.nix";
      #! A voir si on vire pas secrets de vars
      vars = (import ./modules/variables.nix) { inherit secrets; };
      
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        system = system;
        config.allowUnfree = true;
      };
    in {
      devShells.${system}.default = import ./devshell/default.nix { inherit pkgs; };
      
      nixosConfigurations = {
        nixtrizottoserver = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/home-server/configuration.nix
            ./overlays/jellyfin-overlay.nix

            ./modules/sops.nix
            ./modules/entrypoint.nix
            
            ./modules/common/firewall.nix
            ./modules/common/users.nix
            ./modules/common/bash.nix
            ./modules/common/nix.nix
            ./modules/common/crontab.nix

            ({ config, ... }: {
              _module.args.secrets = secrets;
            })
            
            sops-nix.nixosModules.sops

            # make home-manager as a module of nixos
            # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              
              home-manager.users.trizotto = import ./modules/common/trizotto-home.nix;
              home-manager.extraSpecialArgs = { inherit vars; };
              
              # Automatically back up conflicting files with `.backup` extension
              home-manager.backupFileExtension = "backup";
            } 
          ];
          specialArgs = { inherit inputs; };
        };
      };
    };
}
