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

    # Kept separate from `fedimint` so recurringdv2 can track releases
    # independently of the fedimintd hosts.
    fedimint-recurringdv2 = {
      url = "github:fedimint/fedimint?ref=v0.12.1";
    };

    tau = {
      url = "git+https://radicle.dpc.pw/z3ToHcxKefTYxZEoCoDXmddUkK3a4.git?rev=2e7c07eb2c61cac86a2117c33abc1f4653a8804c";
      inputs.linked-specs-skills.follows = "linked-specs-skills";
      # Track published extension trunks independently of the Tau lock.
      inputs.tau-ext-discord.url = "git+https://radicle.dpc.pw/z3xEMWxFEWv7fKYLRhYVCpytsrcSd.git?rev=9b9fad74c668cfe22fdab0a8cda67a80ece1d265";
      inputs.tau-ext-github-standalone.url = "git+https://radicle.dpc.pw/zeY514sMfgDNMC8czs3C1V1MFsaH.git?rev=2fd90d484e90143c0e939c56ef81cbaedcbfb614";
      inputs.tau-ext-pim.url = "git+https://radicle.dpc.pw/z4FCuiVzFns5iTquhsYCntZyVWCqi.git?rev=b51120b7cfef603e5aa3c0cc99cc5809779b9633";
      inputs.tau-ext-rhai.url = "git+https://radicle.dpc.pw/z5RLeoLpNH8Wuba64rZ63u61RkQp.git?rev=159c97766233ef753e501ad16b6009979a9e8477";
      inputs.tau-ext-rostra.url = "git+https://radicle.dpc.pw/z4LrrRivcgNjJii5wzbjTvA8ttt6o.git?rev=5c59e1fdc6eb727c4fb5b92373624077784a592c";
      inputs.tau-ext-slack.url = "git+https://radicle.dpc.pw/z3NJhEtKWCbHPa28wDQSYJ8eEfBjg.git?rev=dfc062e617038a0dbf2df340bd62ca986fe085f5";
      inputs.tau-ext-swarm.url = "git+https://radicle.dpc.pw/z38my9x3Rmn6VYtDMiLKgjK3tRv8o.git?rev=743a47ea1f98abf0296266ac365601a870c91fad";
      inputs.tau-ext-telegram.url = "git+https://radicle.dpc.pw/z3sPdSePnxtBvP9pTLwUwVgpMU68r.git?rev=1cb31ec0b901bc295be30c8770460e714b937b37";
      inputs.tau-ext-xmpp.url = "git+https://radicle.dpc.pw/zpN6uwkd6ok9qRAX5yZaF7w8xzDd.git?rev=cdb9cdb5eea735ff4711d2eb8bc3c2cd356c9978";
      inputs.tau-ext-zulip.url = "git+https://radicle.dpc.pw/z2LFTBWK7VpAwC3Bpxohkh91aqXd.git?rev=47f0501c6a3cc0b584a74c12127be48fbd6757c3";
      inputs.tau-ext-github-standalone.inputs.nixpkgs.follows = "nixpkgs";
      inputs.tau-ext-github-standalone.inputs.flake-utils.follows = "flake-utils";
    };

    isolate.url = "git+https://radicle.dpc.pw/z3qqqx5cpk5jk9ioEGaw54dihfDwb.git?ref=refs/namespaces/z6MkiksiCWT4LDhMQK75t6y3m2gj5iQPE1nhJfJuX1wd5Uef/refs/heads/exec-priv-broker-64-backport&rev=7390f4e82c42d7d6dda38cf62100a47294db2e43";

    # Keep the watch fix without enabling discussion reads on the action PAT.
    gh-isolate.url = "git+https://radicle.dpc.pw/zR8u6vetg8SFDCYwnCAoBuZB32aE.git?rev=c38033c4d3d5cb05dda340386b445b5059762f53";

    clank = {
      url = "git+https://radicle.dpc.pw/z3HjJnZr71vKqT3RUCSaWHfJVUqG1.git?rev=f5becd776f4162a36809ab41173dc533ced33800";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    linked-specs-skills = {
      url = "git+https://radicle.dpc.pw/z2HR882B4c4mTdAgdt4SozpdeTuMf.git?rev=d279f05f6c8355531e2f4eed4c4803ab8c059f2d";
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
      # Use the same upstream binary for the bot and its checks.
      tauPackage = system: inputs.tau.packages.${system}.tau;

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
        imports = [ ./modules/nginx2root.nix ];

        # The emSign roots from NixOS/nixpkgs#576401 are gone upstream;
        # keep blocking the Comodo cross-sign path that remains in the bundle.
        # This affects system trust only, not applications' independent bundles.
        security.pki.caCertificateBlacklist = [
          "Comodo AAA Services root"
        ];

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

      addOperatorAutomationKey =
        name: keys:
        keys
        ++ nixpkgs.lib.optional (builtins.elem name [
          "fedimintd-01"
          "fedimintd-02"
          "fedimintd-03"
          "fedimintd-04"
          "irohdns-eu-01"
          "irohdns-us-01"
          "irohrelay-eu-01"
          "irohrelay-us-01"
          "recurringdv2-01"
        ]) fedimintAutomationPublicKey;

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
            ./modules/monitoring/node-exporter.nix
          ]
          ++ extraModules;
          specialArgs = {
            inherit inputs;
            hostName = name;
            inherit adminKeys;
            rootAuthorizedKeys = adminKeys ++ [ fedimintAutomationPublicKey ];
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
            adminKeys = addOperatorAutomationKey name adminKeysFedimintd;
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
            adminKeys = addOperatorAutomationKey name adminKeys;
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
            adminKeys = addOperatorAutomationKey name adminKeys;
            hostName = name;
          };
        };

      makeRecurringdv2 =
        { name }:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            topLevelModule
            ./modules/nixos-nixpkgs-last-modified.nix

            disko.nixosModules.disko
            agenix.nixosModules.default

            ./hosts/recurringdv2/configuration.nix
          ];
          specialArgs = {
            inherit inputs;
            adminKeys = addOperatorAutomationKey name adminKeys;
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
                weeklySummary = {
                  enable = true;
                  sdkOnCalendar = "Mon *-*-* 07:00:00 America/Los_Angeles";
                };
                dailyPrGrooming.enable = true;
                staleTriage.enable = true;
                papercutGrooming.enable = true;
                workdirCleanup.enable = true;
                # Operator-approved private channel, humans and encrypted
                # credentials; Tau supplies the extension package.
                discord = {
                  enable = true;
                  package = inputs.tau.packages.x86_64-linux.tau-ext-discord;
                  guildId = 990354215060795454;
                  channelId = 1023312920634994838;
                  maintainerRoleId = 1009176569895473223;
                  generalChannelId = 990354215878688860;
                  sdkChannelId = 1299044197805985954;
                  codeReviewChannelId = 1075857804692295720;
                  alerts = {
                    channelId = 1092891381124579349;
                    webhookId = 1092891130166792254;
                  };
                  displayName = "Fedimint maintainers";
                  senderAliases = [
                    {
                      user_id = 332755519561400320;
                      alias = "dpc";
                    }
                    {
                      user_id = 999685318158602331;
                      alias = "m1sterc00lguy";
                    }
                    {
                      user_id = 913133336749305856;
                      alias = "elsirion";
                    }
                  ];
                  allowedUserIds = [
                    332755519561400320 # dpc
                    999685318158602331 # m1sterc00lguy
                    913133336749305856 # elsirion
                  ];
                  tokenAgeFile = ./secrets/tau-fedimint-discord-token.age;
                  identityKeyAgeFile = ./secrets/tau-fedimint-discord-identity-key.age;
                };
                tauPackage = tauPackage "x86_64-linux";
                isolatePackage = inputs.isolate.packages.x86_64-linux.default;
                ghBrokerPackage = inputs.gh-isolate.packages.x86_64-linux.default;
                clankPackage = inputs.clank.packages.x86_64-linux.default;
                skillsSource = inputs.linked-specs-skills;
                githubTokenAgeFile = ./secrets/tau-fedimint-github-token.age;
                sshPrivateKeyAgeFile = ./secrets/tau-fedimint-ssh-private-key.age;
                # The automation key is root-only. This unprivileged bot account
                # remains reachable only with the shared administrator keys.
                sshAuthorizedKeys = adminKeys;
                # Startup subscribes the dedicated bot account to all configured
                # repositories and clears their ignored state. Those persistent
                # GitHub-side effects are explicitly approved for this deployment.
                githubNotifications = {
                  enable = true;
                  package = inputs.tau.packages.x86_64-linux.tau-ext-github-standalone;
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
            ./modules/monitoring/server.nix
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

        # 65.109.14.99
        recurringdv2-01 = makeRecurringdv2 { name = "recurringdv2-01"; };
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
              tauPackage = tauPackage system;
              isolatePackage = inputs.isolate.packages.${system}.default;
              ghBrokerPackage = inputs.gh-isolate.packages.${system}.default;
              githubNotificationsPackage = inputs.tau.packages.${system}.tau-ext-github-standalone;
              skillsSource = inputs.linked-specs-skills;
            };
          };
        }
      );
}
