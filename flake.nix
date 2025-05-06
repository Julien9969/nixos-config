{
  description = "Trizottoserver NixOS config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";  
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in {
        devShells.default = import ./devshell/default.nix { inherit pkgs; };
        
        nixosConfigurations = {
          nixos = nixpkgs.lib.nixosSystem {
            system = system;
            modules = [
              ./hosts/home-server/configuration.nix  
            ];
            specialArgs = { inherit system; };
          };
        };
      }
    );
}
