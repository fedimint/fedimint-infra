{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, disko, ... }:

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
          ./hosts/runner-01/configuration.nix
        ];
      };
    };
}

