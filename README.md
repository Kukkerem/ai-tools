# ai-tools

Reusable AI CLI setup as a standalone flake.

It exposes a Home Manager module that bundles:

- Claude Code
- Codex
- OpenCode
- Shared prompts, agents, and skills
- Individually toggleable local and remote MCP servers

## Included MCPs

This flake enables only local or low-friction MCPs by default. Remote/API-oriented MCPs are available, but disabled by default so consumers can opt in and provide secrets through their own configuration.

Available MCP toggles:

- `sequentialThinking`
- `git`
- `context7`
- `nixos`
- `time`
- `fetch`
- `memory`
- `serena`
- `playwright`
- `filesystem`
- `notebooklm`
- `basicMemory`
- `terraform`
- `qmd`
- `deepwiki`
- `exa`
- `openrouterSearch`

Bundled skills are loaded from `ai-tools/skills`, including browser automation, Caveman modes, DCP, Basic Memory, NotebookLM, RTK, and Karpathy guidelines.

## Flake outputs

- `homeManagerModules.default`
- `homeManagerModules.ai-tools`
- `packages.<system>.default`
- `packages.<system>.mcp`
- `packages.<system>.claude-code`
- `packages.<system>.codex`
- `packages.<system>.opencode`
- `devShells.<system>.default`
- `lib.mkAiToolsDevShell`
- `lib.mkAiToolsDevshellConfig`
- `flakeModules.default`
- `flakeModules.ai-tools-devshell`
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
                context7.enable = false;
                time.enable = true;
                memory.enable = true;
                serena.enable = true;
                filesystem.enable = true;
                nixos.enable = false;
                fetch.enable = false;
                playwright.enable = false;
                deepwiki.enable = false;
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

The template exposes both a Home Manager configuration and a dev shell. Use the
dev shell when you want project-local AI configs without running
`home-manager switch`:

```bash
nix develop
```

### Existing flake with flake-parts

If your project already uses flake-parts, prefer the flake module. It uses
numtide's `devshell` module (`perSystem.devshells`) and still emits the normal
`devShells.<system>.<name>` output:

```nix
{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    ai-tools = {
      url = "github:your-org/ai-tools";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ flake-parts, ai-tools, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [ ai-tools.flakeModules.default ];

      perSystem = { pkgs, ... }: {
        ai-tools.devshells.default = {
          aiTools = {
            mcp.servers = {
              git.enable = true;
              filesystem.enable = true;
              serena.enable = true;
            };
            tools.opencode.plugins = [
              "my-opencode-plugin@latest"
            ];
          };
          extraPackages = [ pkgs.ripgrep ];
        };
      };
    };
}
```

### Existing plain flake

If your project does not use flake-parts, call the reusable helper directly:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    ai-tools = {
      url = "github:your-org/ai-tools";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, ai-tools, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      devShells.${system}.default = ai-tools.lib.mkAiToolsDevShell {
        inherit pkgs;
        aiTools = {
          mcp.servers = {
            git.enable = true;
            filesystem.enable = true;
            serena.enable = true;
          };
          tools.opencode.plugins = [
            "my-opencode-plugin@latest"
          ];
        };
      };
    };
}
```

Advanced users who already import `inputs.devshell.flakeModule` themselves can
use `ai-tools.lib.mkAiToolsDevshellConfig { inherit pkgs; ...; }` inside
`perSystem.devshells.<name>`.

### Adding project-specific MCPs in a dev shell

Use `aiTools.mcp.extraServers` from the consuming flake. Local stdio MCPs use
`command` plus optional `args` and `env`; remote MCPs use `url`:

```nix
devShells.${system}.default = ai-tools.lib.mkAiToolsDevShell {
  inherit pkgs;

  aiTools = {
    tools.opencode.enable = true;

    mcp.extraServers = {
      local-tool = {
        command = "/path/to/example-mcp";
        args = [ "--stdio" ];
      };

      remote-tool = {
        url = "https://example.com/mcp";
      };
    };
  };

  # Add the package here too when the command comes from nixpkgs or another flake.
  extraPackages = [ ];
};
```

To replace a built-in MCP, use `aiTools.mcp.serverOverrides.<name>` instead of
`extraServers`.

## Direct shell usage

You can also use the flake directly as a development shell:

```bash
nix develop github:your-org/ai-tools
```

The shell provides the shared AI tool binaries, MCP-related runtime packages, and
project-local generated config files under `.ai-tools/home`. The shell exports
`HOME`, `XDG_CONFIG_HOME`, and `CODEX_HOME` to that project-local directory so
Claude Code, Codex, and OpenCode can read the generated configs without changing
your real home directory.

To test the generated dev-shell config locally:

```bash
nix develop . --command sh -lc '
  test -f "$XDG_CONFIG_HOME/opencode/opencode.json" &&
  test -f "$XDG_CONFIG_HOME/opencode/dcp.jsonc" &&
  test -f "$XDG_CONFIG_HOME/rtk/config.toml" &&
  test -f "$CODEX_HOME/config.toml" &&
  test -f "$HOME/.claude/CLAUDE.md" &&
  test -x "$(command -v opencode)" &&
  test -x "$(command -v codex)" &&
  test -x "$(command -v claude)" &&
  printf "AI dev shell OK\nHOME=%s\n" "$HOME"
'
```

Useful dev-shell knobs:

```nix
ai-tools.lib.mkAiToolsDevShell {
  inherit pkgs;
  aiTools = {
    # Same shape as programs.ai-tools, without the top-level module path.
    tools.codex.settings.model = "gpt-5.4";
  };
  extraPackages = [ pkgs.ripgrep ];
  extraStartup = ''
    echo "team project shell ready"
  '';
}
```

## Module options

Main entrypoint:

```nix
programs.ai-tools.enable = true;
```

Useful options:

```nix
programs.ai-tools.profileName = "work";
programs.ai-tools.tools.opencode = {
  # Model selection
  model = "claude-sonnet-4-6";          # main model
  smallModel = "openrouter/openai/gpt-5-nano";  # used for lightweight tasks
  theme = "catppuccin";
  disabledProviders = [ "github-copilot" ];

  # LSP support — all enabled by default; disable what you don't need
  lsp = {
    gopls.enable = false;
    pyright.enable = false;
    terraformls.enable = false;
  };

  plugins = [
    # Extra plugins only; auth plugins are included by default.
    "my-opencode-plugin@latest"
  ];

  dcp = {
    enable = true;
    settings.compress.minContextLimit = 60000;
    extraSettings.strategies.purgeErrors.turns = 2;
  };

  rtk = {
    # enable = true by default — works out of the box via llm-agents
    excludeCommands = [ "curl" "cat" ];  # skip RTK for these commands
    tee = {
      enable = true;   # log failed commands for debugging
      mode = "failures";  # "failures" | "all"
    };
    telemetry.enable = false;
  };
};
programs.ai-tools.mcp.memoryBaseDir = "/home/user/.cache/ai-tools";
programs.ai-tools.mcp.filesystem.allowedPaths = [
  "/home/user"
  "/work/project"
];
```

### Multiple OpenCode Profiles

Top-level `programs.ai-tools.tools.opencode.*` options still configure the
default OpenCode profile. Add `profiles` when you need additional isolated
OpenCode configs and wrapper commands:

```nix
programs.ai-tools.tools.opencode = {
  enable = true;

  profiles.work = {
    commandName = "ocw";
    runCommandName = "ocw-run";

    configDir = ".config/opencode-work";
    dataDir = ".local/share/opencode-work";
    stateDir = ".local/state/opencode-work";

    theme = "nightowl";
    plugins = [ "my-work-plugin@latest" ];
    settings.experimental = true;

    dcp.settings.compress.minContextLimit = 50000;
    rtk.excludeCommands = [ "cat" ];

    mcp.memoryDir = "opencode-work";
  };
};
```

Each generated wrapper exports `OPENCODE_CONFIG` and `OPENCODE_CONFIG_DIR` for
its profile. `XDG_DATA_HOME` and `XDG_STATE_HOME` are exported when `dataDir` or
`stateDir` are set.

To wire NixOS options into OpenCode's `nixd` setup:

```nix
programs.ai-tools.nixos = {
  flakePath = "/home/user/nix-config";
  configurationName = "workstation";
};
programs.ai-tools.mcp.servers.nixos.enable = true;
```

MCP server definitions can be overridden without editing this repo:

```nix
programs.ai-tools.mcp = {
  servers = {
    context7.enable = true;
    deepwiki.enable = true;
    filesystem.enable = true;
  };

  serverOverrides.deepwiki = {
    url = "https://mcp.deepwiki.com/mcp";
  };

  extraServers.local-tool = {
    command = "/path/to/local-mcp";
    args = [ "--stdio" ];
  };
};
```

`serverOverrides.<name>` replaces the generated definition for a built-in MCP
server. Use it for full local replacements or for remote URL changes:

```nix
programs.ai-tools.mcp = {
  servers.qmd.enable = true;

  serverOverrides.qmd = {
    command = "/path/to/qmd-mcp";
    args = [ "--stdio" ];
  };
};
```

Tool-specific options can also pass through upstream Home Manager options. Use
`settings` / `extraSettings` for raw config values not covered by dedicated
options, and `program` for upstream Home Manager tool options not modelled by
`programs.ai-tools`:

```nix
programs.ai-tools.tools = {
  claudeCode = {
    model = "claude-sonnet-4-6";
    program.outputStyles.concise = ./claude-output-styles/concise.md;
  };

  codex = {
    settings.model = "gpt-5.4";
    program.skills.local-review = ./skills/local-review;
  };

  opencode = {
    model = "claude-sonnet-4-6";
    theme = "catppuccin";
    smallModel = "openrouter/openai/gpt-5-nano";
    disabledProviders = [ "github-copilot" ];
    extraSettings.mcp = {
      # Final OpenCode settings override, if you need to replace generated MCPs.
    };
    program.web.enable = true;
  };
};
```

OpenCode DCP and RTK are configurable from the module:

```nix
programs.ai-tools.tools.opencode = {
  dcp = {
    enable = true;
    plugin = "@tarquinen/opencode-dcp@latest";
    settings.compress.minContextLimit = 60000;
    extraSettings.strategies.purgeErrors.turns = 2;
  };

  rtk = {
    # enable = true by default — RTK binary sourced automatically via llm-agents
    excludeCommands = [ "nix flake metadata" ];
    tee = {
      enable = true;
      mode = "failures";  # "failures" | "all"
    };
    telemetry.enable = false;
  };

  lsp = {
    gopls.enable = false;
    pyright.enable = false;
    terraformls.enable = false;
    bashls.enable = true;   # default; listed here for clarity
  };
};
```

For secret-backed MCPs, prefer keeping secrets outside this flake and passing a
runtime file path from your own Home Manager/NixOS configuration:

```nix
programs.ai-tools.mcp = {
  servers.openrouterSearch = {
    enable = true;
    apiKeyFile = "/run/secrets/openrouter-api-key";
  };
};
```

For local dev shells, you can also rely on an inherited environment variable.
Enable the server without setting a key in Nix, and export the variable before
starting the shell:

```bash
read -rs OPENROUTER_API_KEY
export OPENROUTER_API_KEY
nix develop .
```

If you want the dev shell to forward the current variable explicitly, add a
devshell env entry in the consuming flake:

```nix
ai-tools.lib.mkAiToolsDevShell {
  inherit pkgs;

  aiTools.mcp.servers.openrouterSearch.enable = true;

  extraEnv = [
    {
      name = "OPENROUTER_API_KEY";
      eval = "$OPENROUTER_API_KEY";
    }
  ];
}
```

A literal key is supported for throwaway/local cases, but avoid it for real
secrets because it can be copied into the Nix store and generated config files:

```nix
programs.ai-tools.mcp.servers.openrouterSearch = {
  enable = true;
  apiKey = "<openrouter-api-key>";
};
```

For fully custom environment handling, replace or extend the server definition:

```nix
programs.ai-tools.mcp.servers.openrouterSearch = {
  enable = true;
  env.OPENROUTER_API_KEY = "<openrouter-api-key>";
};
```

`extraServers` are always added when `programs.ai-tools.enable = true`; built-in servers are controlled by their individual `servers.<name>.enable` toggles.

## Notes

- The module is self-contained and does not require `extraSpecialArgs`.
- `profileName` is used to partition MCP memory files under `mcp.memoryBaseDir`.
- Claude Code and OpenCode reuse the shared prompts, agents, and skills from `ai-tools/`.
- Codex reuses Home Manager's Codex module for config and skills, with bundled prompts still placed under `.codex/prompts/`.
- OpenCode writes optional DCP and RTK support files under each profile's config directory. The default profile also keeps the legacy `.config/rtk/config.toml` path for compatibility.

## Binary cache

Consumers can use the public Cachix cache declared in `nixConfig` automatically
when they trust this flake's configuration:

```text
substituter: https://ai-tools.cachix.org
public key: ai-tools.cachix.org-1:4hlOyu6MVh7DhTl3dG4u1zlyhD834yElTL8bnPu4z2M=
```

For non-interactive commands, pass:

```bash
nix develop github:your-org/ai-tools --accept-flake-config
```

Or add the cache to your own Nix configuration:

```nix
nix.settings = {
  substituters = [ "https://ai-tools.cachix.org" ];
  trusted-public-keys = [
    "ai-tools.cachix.org-1:4hlOyu6MVh7DhTl3dG4u1zlyhD834yElTL8bnPu4z2M="
  ];
};
```

To allow GitHub Actions to push new build results, set this repository secret:

- `CACHIX_AUTH_TOKEN`

## Releasing

Releases are fully automated via `scripts/release.sh` and GitHub Actions.

### Creating a release

```bash
# Ensure you are on main and the tree is clean.
./scripts/release.sh 0.2.0
```

The script:
1. Validates the version argument (semver, no leading `v`).
2. Checks the working tree is clean and the branch is `main`.
3. Bumps `version = "..."` in `flake.nix`.
4. Commits with `chore: bump flake version to v0.2.0`.
5. Creates an annotated tag `v0.2.0`.
6. Pushes the commit and the tag to origin.

### What happens next (GitHub Actions)

Pushing the tag triggers `.github/workflows/release.yml`:

1. **build-and-cache** — builds all outputs and pushes them to Cachix. Pins the
   tag as a versioned pin (`ai-tools-v0.2.0`) so consumers can reference a
   known-good store path.
2. **github-release** — generates release notes from conventional commits via
   `git-cliff` (`cliff.toml`) and creates the GitHub release with those notes.

### Changelog

`CHANGELOG.md` is a manually maintained human summary. Detailed per-commit
release notes are generated by `git-cliff` and published automatically on each
GitHub release. To preview locally:

```bash
nix shell nixpkgs#git-cliff -- git cliff --latest
```

### Flake input updates

A weekly scheduled workflow (`.github/workflows/update-flake-inputs.yml`) runs
`nix flake update` and opens a pull request with the lock file changes.
`dependabot.yml` keeps the GitHub Actions themselves up to date.
