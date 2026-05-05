{
  description = "Local development flake using ai-tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ai-tools.url = "github:zolszabo/ai-tools";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      ai-tools,
      ...
    }:
    let
      # Use the current machine's system automatically.
      # Override with e.g. `system = "aarch64-darwin";` if needed.
      system = builtins.currentSystem;
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # Shared ai-tools configuration used for both the devShell and homeConfiguration.
      aiToolsConfig = {
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
    in
    {
      # `nix develop` — project-local AI home, no system changes needed.
      devShells.${system}.default = ai-tools.lib.mkAiToolsDevShell {
        inherit pkgs;
        aiTools = aiToolsConfig;
      };

      # `home-manager switch --flake .#dev` — full Home Manager integration.
      # Replace "user" / "/home/user" with your real username and home directory.
      homeConfigurations.dev = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ai-tools.homeManagerModules.default
          {
            home.username = "user";
            home.homeDirectory = "/home/user";
            home.stateVersion = "25.05";

            programs.ai-tools = aiToolsConfig;
          }
        ];
      };
    };
}
