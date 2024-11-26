{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix.url = "github:ryantm/agenix";

    perfit = {
      url = "github:rustshop/perfit?rev=56b33333bd7e38b503841a528e6207dab8748fff";
    };

    fedimint = {
      url = "github:fedimint/fedimint?rev=d0877d0310453b737309cef404d98300f3dfa0d2";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    fedimint-ui = {
      url = "github:fedimint/ui?rev=d240b04723d06590d73aa7dc60008dcb8db42733";
    };
  };

  outputs =
    {
      nixpkgs,
      disko,
      agenix,
      flake-utils,
      fedimint,
      fedimint-ui,
      ...
    }@inputs:
    let
      overlays = [
        (final: prev: {
          perfitd = inputs.perfit.packages.${final.system}.perfitd;
          perfit = inputs.perfit.packages.${final.system}.perfit;
          fedimint-ui = fedimint-ui.packages.${final.system}.guardian-ui.overrideAttrs (prev: {
            # TODO:
            # "sha256-qg7h4jCXEudMgG3vCGXO9bS3/az+XpXWnucWM05ri5I="
          });
        })
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

      adminKeys = [
        # dpc
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDRa93v8pzO+EXEH73odhh80VjkLVzPCaRw4K0sObdE9mbZqFB6k791Jm1cVQzHA+sCR4bnyOvA563ExLSGArw4IRxCZvZICSb8RI4QaIhCgf0NtwndKaBxnS2aWrJ/VKNmlZ4OsHMxrFtDRg0AHXBkj0H2O06bJ0+fiwiKdun1tqqi78qQPZkjaJoB227ipx3T0f9Oflj09iWVT3C0saaAiCtpa50ggjImom1FAwNF0gLhPGbSgUzsHzAndwexXWD5StAfWuePaapbQ0IIAY9ahlTKCXGSV0oS/IrBDjOfIaXoyzzgT4/xTz6dwie2g255mGTDn6k0CYkWX19H8xzT2TQ7e4ikNrXVdcRRRy4rd22MA75546RVD2mm36C0DnaUsnBUwymuQ02z33iTm8U7CZXQWpiKjwgqCtvs9zrsRx1YECHCw5ehUDt2nMw4ino42jthxV9bgQDQg/On7frBUXeKkd7L0UVfC71DW9AQQTvdHA2POpPhtoi7BznOeFMoVXxBMgJSgwGTH3ErY0zbvMLJNNROXby4rABmb7XTl5bav5DYD2lWzhcseN6a+/PgREyzllQxJqWQVQvA00JFuaNFLI7JeyIULUgyYuS5n/jEvmKKnzhwuGlHnIKF5UPViaF3WRiFSTop6taZNptBFWGBsG7eT8rTxb/FKtylVw== cardno:20_514_157"
        # elsirion
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC+t2YktQZWLbv2BmIkWv9G98L5nNwnsVGMszcbnTu3W25bp0CJ4MtBmvmagygfAd+td9dPe44assaU5XNk1+eK9CMx3X3LlkJ4sVr6EYDG+HrBiFSWSIGlYA6EblXXiCIzKh6i+dAM+c35YUZLBxfKaqaWEF1REiR7O1DQxH6TU3qCMStxY5PF1rtiLjVHPBTiWv41zynRRqfA5L+sE+/NYrZj6NIKL5p6zAhKwV8YRavVTOzGDr+Rn+10t907JHjydFK6LfKpUADr4c/XkMY8IRgKCZsBeu9C+N2y93CbyfPua5+s/6caO6wHNjBYi2599Ky84XBtVt/WUQtq5WwXAe97j6Z+3M8bEqUFLUQxQh4r1hOE9ApEUYY6T//wDvqPDVMsKTkMe8HiAjOZawjzjQWYutAjGjuug9efFoP9WJ39J3SfmTDUHo+4Pyf+2ntqUyp6SMmBu7eTHOw1a4kDaQvIltBcokdhMm12RNdTwCLMS0YvFiRcJmzuemiTw78="
      ];

      adminKeysFedimintd = adminKeys ++ [
        # dpc
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDcuMO6k5zhp7JTnp4Kz4gjWqOo+TDbaBlD2d/LICHSv5DAiQy/mgRcgfKZrb4LSA08FmbMjzp2cJoNGTG249vABdizEzTXUnQ+8QzS3VKkfZw5D86+EyOXCwhD2YwGS4A7nzUaStROlQ+lyVMeR8DpbbCSVrx0VMdP48SwJA5pSGHPuXJsYElfGOttQrIWAqvdK8CxG+BmdgmzLpb7b9KlJ5TetUmn03+zsE587EcdvtNU9jCmbJ5uFLR5x9zZGhF5HNA/XqSiiPkbAfcAc/mEwVaSP6ZeOKXg9M1LXeeG/+/oDYLJU6Ra3pVL50aw6L7UEOoUt0Vcf394famZaugFxcRGuvK6ox0tWhvrcO2Oj8Ko9FHTHD0XfEXazpXmW9eDa9rLYNgdY9li/pD2T71VqZrnr7Xq8J676srbvHp7RO8Wz4RRnwbmpfm1107oiZegu1kxCOvJmlZeBef/9EE0lYKi7/XfmKD3uAS5UJa/dvFysI6aUX1X0duNUedmkgSAhTz8yw7sVB/zarDf21AyCuwc8MZ9rcdMYMsCvpF/p/0BfddV5cI7juXWnbH9Zbfct+XJj1OqS46G9wieKslrJEZ94ZLrghe0wE5Ip1kuYHVIlZzDw0UXm4j0wfsZCw8w/RIZDojwnr992xKSWHyyNxjRVfp77BqoxECopJOO7w== bradley@sparkswap.com"
      ];

      makeRunner =
        {
          name,
          extraModules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            topLevelModule

            disko.nixosModules.disko
            agenix.nixosModules.default
            inputs.perfit.nixosModules.perfitd

            ./hosts/runner/configuration.nix
          ] ++ extraModules;
          specialArgs = {
            inherit inputs;
            hostName = name;
            inherit adminKeys;
          };
        };
      makeFedimintd =
        {
          name,
          extraModules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            topLevelModule

            disko.nixosModules.disko
            agenix.nixosModules.default
            inputs.perfit.nixosModules.perfitd

            ./hosts/fedimintd/configuration.nix
          ] ++ extraModules;
          specialArgs = {
            inherit inputs;
            hostName = name;
            adminKeys = adminKeysFedimintd;
          };
        };
    in
    {
      nixosConfigurations = {
        runner-01 = makeRunner { name = "runner-01"; };
        runner-02 = makeRunner { name = "runner-02"; };
        # runner-03 = makeRunner { name = "runner-03"; };
        runner-04 = makeRunner {
          name = "runner-04";
          extraModules = [
            (import ./modules/perfit.nix)
            (import ./modules/radicle.nix)
          ];
        };
        fedimintd-01 = makeFedimintd { name = "fedimintd-01"; };
        fedimintd-02 = makeFedimintd { name = "fedimintd-02"; };
        fedimintd-03 = makeFedimintd { name = "fedimintd-03"; };
        fedimintd-04 = makeFedimintd { name = "fedimintd-04"; };
      };
    }
    //

      flake-utils.lib.eachDefaultSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          devShells = {
            default = pkgs.mkShell {
              packages = [
                inputs.agenix.packages.${pkgs.system}.default
                inputs.perfit.packages.${pkgs.system}.perfit
              ];
            };
          };
        }
      );
}
