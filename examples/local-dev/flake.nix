{
  description = "Example project-local AI dev shell using ai-tools (no system changes)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    ai-tools.url = "github:Kukkerem/ai-tools";
  };

  outputs =
    { nixpkgs, ai-tools, ... }:
    let
      # Detect the current machine's system. Override with a literal
      # (e.g. "aarch64-darwin") if needed.
      system = builtins.currentSystem;
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true; # claude-code / codex are unfree
      };
    in
    {
      # `nix develop` builds a project-local AI home under .ai-tools/home/.
      # The agents (claude / codex / opencode / omp) run with that directory
      # as HOME, so nothing touches your real ~ or any system config. The
      # config is regenerated from this flake on every shell entry.
      devShells.${system}.default = ai-tools.lib.mkAiToolsDevShell {
        inherit pkgs;

        aiTools = {
          enable = true;

          tools = {
            opencode.enable = true;
            omp.enable = true;
          };

          # All MCP servers are disabled by default; enable only what you need.
          mcp.servers = {
            git.enable = true;
            context7.enable = true;
            nixos.enable = true;
            deepwiki.enable = true;
          };
        };

        # Extra packages dropped into the dev-shell PATH alongside the agents.
        extraPackages = [
          pkgs.ripgrep
          pkgs.jq
        ];
      };
    };
}
