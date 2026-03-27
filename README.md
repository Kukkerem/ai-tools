# ai-tools

Reusable AI CLI setup as a standalone flake.

It exposes a Home Manager module that bundles:

- Claude Code
- Codex
- OpenCode
- Shared prompts, agents, and skills
- Individually toggleable local MCP servers

## Included MCPs

This flake intentionally keeps only local or low-friction MCPs and excludes API-oriented ones like DeepL and Grafana.

Available MCP toggles:

- `sequentialThinking`
- `git`
- `nixos`
- `time`
- `memory`
- `serena`
- `playwright`
- `filesystem`

## Flake outputs

- `homeManagerModules.default`
- `homeManagerModules.ai-tools`
- `packages.<system>.default`
- `packages.<system>.mcp`
- `packages.<system>.claude-code`
- `packages.<system>.codex`
- `packages.<system>.opencode`
- `devShells.<system>.default`
- `templates.local-dev`

## Home Manager usage

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ai-tools.url = "github:your-org/ai-tools";
  };

  outputs = { nixpkgs, home-manager, ai-tools, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      homeConfigurations.user = home-manager.lib.homeManagerConfiguration {
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
                nixos.enable = false;
                playwright.enable = false;
              };
            };
          }
        ];
      };
    };
}
```

## Local development flake usage

You can scaffold an example with:

```bash
nix flake init -t github:your-org/ai-tools#local-dev
```

Or inspect the bundled template in `templates/local-dev`.

## Direct shell usage

You can also use the flake directly as a development shell:

```bash
nix develop github:your-org/ai-tools
```

This shell provides the shared AI tool binaries and MCP-related runtime packages.
For full generated config files, use the Home Manager module or the bundled template.

## Module options

Main entrypoint:

```nix
programs.ai-tools.enable = true;
```

Useful options:

```nix
programs.ai-tools.profileName = "work";
programs.ai-tools.mcp.memoryBaseDir = "/home/user/.cache/ai-tools";
programs.ai-tools.mcp.filesystem.allowedPaths = [
  "/home/user"
  "/work/project"
];
```

To wire NixOS options into OpenCode's `nixd` setup:

```nix
programs.ai-tools.nixos = {
  flakePath = "/home/user/nix-config";
  configurationName = "workstation";
};
programs.ai-tools.mcp.servers.nixos.enable = true;
```

## Notes

- The module is self-contained and does not require `extraSpecialArgs`.
- Claude Code and OpenCode reuse the shared prompts, agents, and skills from `ai-tools/`.
- Codex gets generated config, prompts, and skills under `.codex/`.

## Binary cache

Consumers can use the public Cachix cache declared in the flake automatically.

To allow GitHub Actions to push new build results, set this repository secret:

- `CACHIX_AUTH_TOKEN`
