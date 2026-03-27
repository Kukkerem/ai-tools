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

    llm-agents.url = "github:numtide/llm-agents.nix";

    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mcp-nixos.url = "github:utensils/mcp-nixos";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
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
          f (
            import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            }
          )
        );

      aiToolsModule = import ./modules/home-manager { inherit inputs; };
    in
    {
      homeManagerModules = {
        default = aiToolsModule;
        ai-tools = aiToolsModule;
      };

      formatter = forEachSystem (
        pkgs:
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

      checks = forEachSystem (pkgs: {
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
                  mcp.servers = {
                    sequentialThinking.enable = true;
                    git.enable = true;
                    time.enable = true;
                    memory.enable = true;
                    serena.enable = true;
                    filesystem.enable = true;
                  };
                };
              }
            ];
          }).activationPackage;
      });

      templates.local-dev = {
        path = ./templates/local-dev;
        description = "Local development flake wired to the ai-tools Home Manager module";
      };
    };
}
