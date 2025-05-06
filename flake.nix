{
  description = "Trizottoserver NixOS config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";  
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, ... }: 
    let
      pkgs = import nixpkgs {
        config.allowUnfree = true;
      };
    in {
      devShells.default = import ./devshell/default.nix { inherit pkgs; };
      
      nixosConfigurations.trizottoserver = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/home-server/configuration.nix  
          ];
          specialArgs = { inherit inputs; };
      };
    };
}
