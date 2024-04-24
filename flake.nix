{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix.url = "github:ryantm/agenix";
  };

  outputs = { nixpkgs, disko, agenix, flake-utils, ... }@inputs:

    let

      overlays = [
        (final: prev: { })
      ];

      topLevelModule = {
        nixpkgs = {
          inherit overlays;
        };
        nix = {
          registry = {
            nixpkgs.flake = nixpkgs;
          };
          nixPath = [ "nixpkgs=${nixpkgs}" ];
        };
      };

    in
    {
      nixosConfigurations.runner-01 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          topLevelModule

          disko.nixosModules.disko
          agenix.nixosModules.default
          ./hosts/runner-01/configuration.nix
        ];
        specialArgs = { inherit inputs; };
      };

    } //

    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          lib = pkgs.lib;
        in
        {
          devShells = {
            default = pkgs.mkShell {
              packages = [
                inputs.agenix.packages."${pkgs.system}".default

              ];
            };
          };

        }


      );
}

