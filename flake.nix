{
  inputs = {
    # https://github.com/NixOS/nixpkgs/pull/397967
    # nixpkgs.url = "github:NixOS/nixpkgs?rev=4f993a759ef3a1432653ce5f117ba7725771c0d8";
    nixpkgs.url = "github:NixOS/nixpkgs/25.05";

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
      # url = "github:fedimint/fedimint?ref=v0.7.1";
      url = "github:fedimint/fedimint?rev=de7448559f5ddcff63698d624d6592156870a533";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      disko,
      agenix,
      flake-utils,
      fedimint,
      ...
    }@inputs:
    let
      overlays = [
        (final: prev: {
          perfitd = inputs.perfit.packages.${final.system}.perfitd;
          perfit = inputs.perfit.packages.${final.system}.perfit;
          fedimint-cli = fedimint.packages.${final.system}.fedimint-cli;
          fedimintd = fedimint.packages.${final.system}.fedimintd;
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
        # brad
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGP9AbqO9klB18SWLZcAzy88nqgkggyC4kjyaCCW8vDp l14-gen3"
      ];

      makeRunner =
        {
          system,
          name,
          runners,
          extraModules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
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
            inherit runners;
          };
        };

      makeRunnerAmd = { extraModules ? [], ... }@args:
        makeRunner (args // {
          system = "x86_64-linux";
          extraModules = [
            ./disk-config/hetzner-ax162.nix
            ./hosts/runner/hardware-configuration-amd.nix
            ./hosts/runner/check-temp.nix
          ] ++ extraModules;
          runners = ["a" "b" "c" "d"];
        });

      makeRunnerArm = { extraModules ? [], ... }@args:
        makeRunner (args // {
          system = "aarch64-linux";
          extraModules = [
            ./disk-config/hetzner-vps.nix
            ./hosts/runner/hardware-configuration-arm.nix
          ] ++ extraModules;
          runners = [ "a" ];
        });

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

            {
              disabledModules = [ "services/networking/fedimintd.nix" ];
            }
            inputs.fedimint.nixosModules.fedimintd

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
        runner-01 = makeRunnerAmd { name = "runner-01"; };
        runner-02 = makeRunnerAmd { name = "runner-02"; };
        # runner-03 = makeRunner { name = "runner-03"; };
        runner-04 = makeRunnerAmd {
          name = "runner-04";
          extraModules = [
            ./modules/perfit.nix
            ./modules/radicle.nix
          ];
        };

        runner-arm-01 = makeRunnerArm { name = "runner-arm-01"; };

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
                pkgs.just
              ];
            };
          };
        }
      );
}
