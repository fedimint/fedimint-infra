{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

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
    };

    tau = {
      url = "git+https://radicle.dpc.pw/z3ToHcxKefTYxZEoCoDXmddUkK3a4.git?rev=30c8b43410a84294f31f74451f9f7f09a94df473";
    };

    tau-ext-github = {
      url = "git+https://iris.radicle.xyz/zeY514sMfgDNMC8czs3C1V1MFsaH.git?rev=f67822edfcec845f34f6c9f09381947bf2acc008";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    isolate.url = "git+https://radicle.dpc.pw/z3qqqx5cpk5jk9ioEGaw54dihfDwb.git?rev=0ecb5af2b5f584cb2f126d0c76f03508ac93ed4f";

    gh-isolate.url = "git+https://radicle.dpc.pw/zR8u6vetg8SFDCYwnCAoBuZB32aE.git?rev=7815eeb170eeefa7aca7b027e5e5491f2311a689";

    clank = {
      url = "git+https://radicle.dpc.pw/z3HjJnZr71vKqT3RUCSaWHfJVUqG1.git?rev=56a03fecf62ca8090c3e5f5a089b6d9c62483c8d";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    linked-specs-skills = {
      url = "git+https://radicle.dpc.pw/z2HR882B4c4mTdAgdt4SozpdeTuMf.git?rev=4e7ee93f8874aa7198a1be41368e44d10ef4fad5";
      flake = false;
    };

    fedimint-skills = {
      url = "github:fedimint/fedimint?rev=57c7e8c57c584650b85eb55eb6d2f8ba605f4798";
      flake = false;
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
          # we need yet unreleased 0.9.0 version of rqbit for `rqbit share`
          rqbit = final.callPackage ./nix/pkgs/rqbit.nix { };
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

      dpcKeys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDRa93v8pzO+EXEH73odhh80VjkLVzPCaRw4K0sObdE9mbZqFB6k791Jm1cVQzHA+sCR4bnyOvA563ExLSGArw4IRxCZvZICSb8RI4QaIhCgf0NtwndKaBxnS2aWrJ/VKNmlZ4OsHMxrFtDRg0AHXBkj0H2O06bJ0+fiwiKdun1tqqi78qQPZkjaJoB227ipx3T0f9Oflj09iWVT3C0saaAiCtpa50ggjImom1FAwNF0gLhPGbSgUzsHzAndwexXWD5StAfWuePaapbQ0IIAY9ahlTKCXGSV0oS/IrBDjOfIaXoyzzgT4/xTz6dwie2g255mGTDn6k0CYkWX19H8xzT2TQ7e4ikNrXVdcRRRy4rd22MA75546RVD2mm36C0DnaUsnBUwymuQ02z33iTm8U7CZXQWpiKjwgqCtvs9zrsRx1YECHCw5ehUDt2nMw4ino42jthxV9bgQDQg/On7frBUXeKkd7L0UVfC71DW9AQQTvdHA2POpPhtoi7BznOeFMoVXxBMgJSgwGTH3ErY0zbvMLJNNROXby4rABmb7XTl5bav5DYD2lWzhcseN6a+/PgREyzllQxJqWQVQvA00JFuaNFLI7JeyIULUgyYuS5n/jEvmKKnzhwuGlHnIKF5UPViaF3WRiFSTop6taZNptBFWGBsG7eT8rTxb/FKtylVw== cardno:20_514_157"
      ];

      adminKeys = dpcKeys ++ [
        # elsirion
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC+t2YktQZWLbv2BmIkWv9G98L5nNwnsVGMszcbnTu3W25bp0CJ4MtBmvmagygfAd+td9dPe44assaU5XNk1+eK9CMx3X3LlkJ4sVr6EYDG+HrBiFSWSIGlYA6EblXXiCIzKh6i+dAM+c35YUZLBxfKaqaWEF1REiR7O1DQxH6TU3qCMStxY5PF1rtiLjVHPBTiWv41zynRRqfA5L+sE+/NYrZj6NIKL5p6zAhKwV8YRavVTOzGDr+Rn+10t907JHjydFK6LfKpUADr4c/XkMY8IRgKCZsBeu9C+N2y93CbyfPua5+s/6caO6wHNjBYi2599Ky84XBtVt/WUQtq5WwXAe97j6Z+3M8bEqUFLUQxQh4r1hOE9ApEUYY6T//wDvqPDVMsKTkMe8HiAjOZawjzjQWYutAjGjuug9efFoP9WJ39J3SfmTDUHo+4Pyf+2ntqUyp6SMmBu7eTHOw1a4kDaQvIltBcokdhMm12RNdTwCLMS0YvFiRcJmzuemiTw78="
        # Bradley
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGP9AbqO9klB18SWLZcAzy88nqgkggyC4kjyaCCW8vDp l14-gen3"
      ];

      adminKeysFedimintd = adminKeys ++ [
      ];

      fedimintAutomationPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ3EKT3vVlYnZ4v3jBBlt+ug6Q+msgQEFT+ErT6ZDEs5 fedimint-infra-agent@dpc.pw";

      runnerRootAuthorizedKeys =
        hostName: adminKeys ++ nixpkgs.lib.optional (hostName == "runner-01") fedimintAutomationPublicKey;

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
            ./modules/nixos-nixpkgs-last-modified.nix

            disko.nixosModules.disko
            agenix.nixosModules.default
            inputs.perfit.nixosModules.perfitd

            ./hosts/runner/configuration.nix
          ]
          ++ extraModules;
          specialArgs = {
            inherit inputs;
            hostName = name;
            inherit adminKeys;
            rootAuthorizedKeys = runnerRootAuthorizedKeys name;
            inherit runners;
          };
        };

      makeRunnerAmd =
        {
          extraModules ? [ ],
          ...
        }@args:
        makeRunner (
          args
          // {
            system = "x86_64-linux";
            extraModules = [
              ./disk-config/hetzner-ax162.nix
              ./hosts/runner/hardware-configuration-amd.nix
              ./hosts/runner/nix-build-tmpfs.nix
              ./hosts/runner/check-temp.nix
              ./modules/seed-assumeutxo.nix
            ]
            ++ extraModules;
            runners = [
              "a"
              "b"
              "c"
              "d"
            ];
          }
        );

      makeRunnerArm =
        {
          extraModules ? [ ],
          ...
        }@args:
        makeRunner (
          args
          // {
            system = "aarch64-linux";
            extraModules = [
              ./disk-config/hetzner-vps.nix
              ./hosts/runner/hardware-configuration-arm.nix
            ]
            ++ extraModules;
            runners = [
              "a"
              "b"
            ];
          }
        );

      makeFedimintd =
        {
          name,
          extraModules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [
            topLevelModule
            ./modules/nixos-nixpkgs-last-modified.nix

            disko.nixosModules.disko
            agenix.nixosModules.default
            inputs.perfit.nixosModules.perfitd

            {
              disabledModules = [ "services/networking/fedimintd.nix" ];
            }
            inputs.fedimint.nixosModules.fedimintd

            ./hosts/fedimintd/configuration.nix
          ]
          ++ extraModules;
          specialArgs = {
            inherit inputs;
            hostName = name;
            adminKeys = adminKeysFedimintd;
          };
        };

      makeIrohDns =
        { name, serverIp, ... }@args:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            topLevelModule
            ./modules/nixos-nixpkgs-last-modified.nix

            disko.nixosModules.disko
            agenix.nixosModules.default

            ./hosts/iroh-dns/configuration.nix
          ];
          specialArgs = {
            inherit inputs;
            inherit adminKeys;
            inherit serverIp;
            hostName = name;
          };
        };

      makeIrohRelay =
        { name, ... }@args:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            topLevelModule
            ./modules/nixos-nixpkgs-last-modified.nix

            disko.nixosModules.disko
            agenix.nixosModules.default

            ./hosts/iroh-relay/configuration.nix
          ];
          specialArgs = {
            inherit inputs;
            inherit adminKeys;
            hostName = name;
          };
        };
      nixosConfigurations = {
        runner-01 = makeRunnerAmd {
          name = "runner-01";
          extraModules = [
            ./modules/tau-fedimint-bot.nix
            {
              services.tau-fedimint-bot = {
                enable = true;
                tauPackage = inputs.tau.packages.x86_64-linux.tau;
                isolatePackage = inputs.isolate.packages.x86_64-linux.default;
                ghBrokerPackage = inputs.gh-isolate.packages.x86_64-linux.default;
                clankPackage = inputs.clank.packages.x86_64-linux.default;
                skillsSource = inputs.linked-specs-skills;
                fedimintSkillsSource = inputs.fedimint-skills;
                githubTokenAgeFile = ./secrets/tau-fedimint-github-token.age;
                sshPrivateKeyAgeFile = ./secrets/tau-fedimint-ssh-private-key.age;
                # The automation key is root-only. This unprivileged bot account
                # remains reachable only with the shared administrator keys.
                sshAuthorizedKeys = adminKeys;
                # Startup subscribes the dedicated bot account to both configured
                # repositories and clears their ignored state. Those persistent
                # GitHub-side effects are explicitly approved for this deployment.
                githubNotifications = {
                  enable = true;
                  package = inputs.tau-ext-github.packages.x86_64-linux.default;
                  tokenAgeFile = ./secrets/tau-fedimint-github-notifications-token.age;
                  identityKeyAgeFile = ./secrets/tau-fedimint-github-notifications-identity-key.age;
                };
              };
            }
          ];
        };
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

        irohdns-eu-01 = makeIrohDns {
          name = "irohdns-eu-01";
          serverIp = "157.180.123.56";
        };
        irohrelay-eu-01 = makeIrohRelay { name = "irohrelay-eu-01"; };
        irohdns-us-01 = makeIrohDns {
          name = "irohdns-us-01";
          serverIp = "5.78.106.169";
        };
        irohrelay-us-01 = makeIrohRelay { name = "irohrelay-us-01"; };
      };
    in
    {
      inherit nixosConfigurations;
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
          checks = nixpkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
            tau-fedimint-bot-config = import ./tests/tau-fedimint-bot.nix {
              inherit system nixpkgs agenix;
              module = ./modules/tau-fedimint-bot.nix;
              tauPackage = inputs.tau.packages.${system}.tau;
              isolatePackage = inputs.isolate.packages.${system}.default;
              ghBrokerPackage = inputs.gh-isolate.packages.${system}.default;
              skillsSource = inputs.linked-specs-skills;
              fedimintSkillsSource = inputs.fedimint-skills;
              githubNotificationsPackage = inputs.tau-ext-github.packages.${system}.default;
            };
            runner-01-root-ssh-authorization = import ./tests/runner-01-root-ssh-authorization.nix {
              inherit system nixpkgs;
              automationPublicKey = fedimintAutomationPublicKey;
              adminKeys = adminKeys;
              runner01RootAuthorizedKeys =
                nixosConfigurations.runner-01.config.users.users.root.openssh.authorizedKeys.keys;
              runner02RootAuthorizedKeys =
                nixosConfigurations.runner-02.config.users.users.root.openssh.authorizedKeys.keys;
              botAuthorizedKeys =
                nixosConfigurations.runner-01.config.users.users.tau-fedimint.openssh.authorizedKeys.keys;
            };
            tau-fedimint-github-password-backup = import ./tests/tau-fedimint-github-password-backup.nix {
              inherit system nixpkgs nixosConfigurations;
              secretPolicies = import ./secrets.nix;
            };
          };
        }
      );
}
