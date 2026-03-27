{
  description = "Local development flake using ai-tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ai-tools.url = "path:../..";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      ai-tools,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      homeConfigurations.dev = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ai-tools.homeManagerModules.default
          {
            home.username = "user";
            home.homeDirectory = "/home/user";
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
      };
    };
}
