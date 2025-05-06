#let 
#  secret = import ./modules/variables/secret.nix;
#in
{
  description = "Trizottoserver NixOS config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";  
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, home-manager, ... }: 
    let
      pkgs = import nixpkgs {
        config.allowUnfree = true;
      };
    in {
      devShells.default = import ./devshell/default.nix { inherit pkgs; };
      
      nixosConfigurations = {
        trizottoserver = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/home-server/configuration.nix 
            
            # make home-manager as a module of nixos
            # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              
              home-manager.users.trizotto = import ./modules/common/trizotto-home.nix;
              
              # Automatically back up conflicting files with `.backup` extension
              home-manager.backupFileExtension = "backup";
              # Optionally, use home-manager.extraSpecialArgs to pass arguments to home.nix
            } 
          ];
          specialArgs = { inherit inputs; };
      };
    };
}
