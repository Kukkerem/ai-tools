{
  description = "Reusable Home Manager AI tools flake with optional MCP servers";

  nixConfig = {
    extra-substituters = [
      "https://cache.numtide.com"
      "https://ai-tools.cachix.org"
    ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "ai-tools.cachix.org-1:4hlOyu6MVh7DhTl3dG4u1zlyhD834yElTL8bnPu4z2M="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents.url = "github:numtide/llm-agents.nix";

    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mcp-nixos.url = "github:utensils/mcp-nixos";

    terraform-skill = {
      url = "github:antonbabenko/terraform-skill";
      flake = false;
    };

    caveman = {
      url = "github:JuliusBrussee/caveman/18e45320a0b1aecc959a807f8568ee44b3aaa055";
      flake = false;
    };

    superpowers = {
      url = "github:obra/superpowers/f2cbfbefebbfef77321e4c9abc9e949826bea9d7";
      flake = false;
    };

    mattpocock-skills = {
      url = "github:mattpocock/skills/694fa30311e02c2639942308513555e61ee84a6f";
      flake = false;
    };

    mcp-openrouter-search.url = "github:Kukkerem/mcp-openrouter-search/v0.1.4";
    nix-openclaw-tools.url = "github:openclaw/nix-openclaw-tools";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      # Bumped by scripts/release.sh on each release tag.
      # Keep in sync with the git tag: v<version>.
      version = "0.1.10";

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forEachSystem =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          let
            pkgs = import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            };
          in
          f {
            inherit pkgs system;
            lib = nixpkgs.lib;
            packageSets = import ./lib/packages.nix {
              inherit inputs pkgs;
              lib = nixpkgs.lib;
            };
          }
        );

      aiToolsModule = import ./modules/home-manager { inherit inputs; };
      devShellSupport = import ./lib/dev-shell.nix {
        inherit inputs home-manager;
        lib = nixpkgs.lib;
      };

      mkTestChecks =
        { lib, pkgs }:
        {
          lib-tests = import ./tests/lib.nix { inherit inputs lib pkgs; };
          home-manager-tests = import ./tests/home-manager.nix {
            inherit
              aiToolsModule
              inputs
              lib
              pkgs
              ;
          };
          nixos-module-tests = import ./tests/nixos.nix { inherit inputs pkgs; };
        };
    in
    {
      lib = {
        inherit (devShellSupport)
          mkAiToolsDevShell
          mkAiToolsDevshellConfig
          ;
      };

      flakeModules = {
        default = import ./flake-modules/devshell.nix { inherit devShellSupport inputs; };
        ai-tools-devshell = import ./flake-modules/devshell.nix { inherit devShellSupport inputs; };
      };

      homeManagerModules = {
        default = aiToolsModule;
        ai-tools = aiToolsModule;
      };

      # Convenience wrapper for NixOS configurations that already import
      # home-manager as a NixOS module. Add to your NixOS modules list and
      # the ai-tools Home Manager module becomes available to every user
      # configured via `home-manager.users.<name>`.
      nixosModules = {
        default = import ./modules/nixos { inherit inputs; };
        ai-tools = import ./modules/nixos { inherit inputs; };
      };

      formatter = forEachSystem (
        { pkgs, ... }:
        pkgs.writeShellApplication {
          name = "format-ai-tools";
          runtimeInputs = [
            pkgs.findutils
            pkgs.nixfmt
          ];
          text = ''
            if [ "$#" -eq 0 ]; then
              find . -type f -name '*.nix' -print0 | xargs -0 nixfmt
            else
              exec nixfmt "$@"
            fi
          '';
        }
      );

      packages = forEachSystem (
        {
          packageSets,
          ...
        }:
        {
          default = packageSets.bundles.default;
          mcp = packageSets.bundles.mcp;
          claude-code = packageSets.toolPackages.claudeCode;
          codex = packageSets.toolPackages.codex;
          opencode = packageSets.toolPackages.opencode;
          omp = packageSets.toolPackages.omp;
        }
      );

      devShells = forEachSystem (
        { pkgs, ... }:
        {
          default = devShellSupport.mkAiToolsDevShell { inherit pkgs; };
        }
      );

      checks = forEachSystem (
        { lib, pkgs, ... }:
        (mkTestChecks { inherit lib pkgs; })
        // {
          default =
            (home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              modules = [
                aiToolsModule
                {
                  home.username = "tester";
                  home.homeDirectory = "/home/tester";
                  home.stateVersion = "25.05";

                  programs.ai-tools = {
                    enable = true;
                    tools = {
                      claudeCode.enable = true;
                      codex.enable = true;
                      opencode.enable = true;
                    };
                    tools.opencode = {
                      settings.theme = "catppuccin";
                      dcp.settings.compress.minContextLimit = 42000;
                      rtk = {
                        excludeCommands = [ "nix flake metadata" ];
                        tee = {
                          enable = true;
                          mode = "failures";
                        };
                        telemetry.enable = false;
                      };
                      profiles.work = {
                        commandName = "ocw";
                        runCommandName = "ocw-run";
                        configDir = ".config/opencode-work";
                        dataDir = ".local/share/opencode-work";
                        stateDir = ".local/state/opencode-work";
                        theme = "nightowl";
                        plugins = [ "example-opencode-plugin@latest" ];
                        settings.experimental = true;
                        extraRuntimePackages = [ pkgs.hello ];
                        dcp.settings.compress.minContextLimit = 50000;
                        rtk.excludeCommands = [ "cat" ];
                        mcp = {
                          memoryDir = "opencode-work";
                          servers = {
                            context7.enable = false;
                            openrouter-search = {
                              enable = true;
                              apiKeyFile = "/run/secrets/openrouter-work-api-key";
                            };
                          };
                          extraServers.cloudflare-docs = {
                            url = "https://docs.mcp.cloudflare.com/mcp";
                          };
                        };
                        extraFiles."plugin-config.jsonc".value = {
                          enabled = true;
                          nested.option = "value";
                        };
                      };
                    };
                    mcp = {
                      servers = {
                        sequential-thinking.enable = true;
                        git.enable = true;
                        context7.enable = true;
                        time.enable = true;
                        memory.enable = true;
                        serena.enable = true;
                        filesystem.enable = true;
                        deepwiki.enable = true;
                      };
                      serverOverrides.deepwiki = {
                        url = "https://mcp.deepwiki.com/mcp";
                      };
                      extraServers.example-local = {
                        command = lib.getExe pkgs.hello;
                      };
                    };
                  };
                }
              ];
            }).activationPackage;
        }
      );

      templates.local-dev = {
        path = ./templates/local-dev;
        description = "Local development flake wired to the ai-tools Home Manager module";
      };
    };
}
