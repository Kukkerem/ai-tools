# ai-tools

Reusable Home Manager AI tools flake. One module to configure Claude Code, Codex, OpenCode, and omp with shared skills, agents, commands, and MCP servers.

All options live under `programs.ai-tools`. Config files are fully managed by Nix — immutable, regenerated on every `home-manager switch`.

```nix
programs.ai-tools = {
  enable = true;
  tools = {
    claudeCode.enable = true;
    codex.enable = true;
    opencode.enable = true;
    omp.enable = true;
  };
};
```

## AI Coding Agents

| Agent | Module path | Wrapper | Supports |
|-------|------------|---------|----------|
| Claude Code | `tools.claudeCode` | `claude` | Agents, commands, skills, MCP, memory |
| Codex | `tools.codex` | `codex` | Prompts, skills, MCP, memories |
| OpenCode | `tools.opencode` | `opencode` | Profiles, LSP, DCP, RTK, MCP, agents/commands/skills |
| omp (oh-my-pi) | `tools.omp` | `omp` | Profiles, hooks, extensions, MCP, agents/commands/skills |

All four share the same agents, commands, and skills from `ai-tools/`. Each tool gets config files generated under its own directory (`~/.claude/`, `~/.codex/`, `~/.config/opencode/`, `~/.omp/`).

## MCP Servers

17 servers available, **all disabled by default**. Enable only what you need:

| Server | Type | Requires |
|--------|------|----------|
| `sequential-thinking` | Local | — |
| `git` | Local | — |
| `context7` | Local | — |
| `nixos` | Local | NixOS config path |
| `time` | Local | — |
| `fetch` | Local | — |
| `memory` | Local | Memory dir |
| `serena` | Local | Project path |
| `playwright` | Local | Chromium |
| `filesystem` | Local | Allowed paths |
| `notebooklm` | Local | Google auth |
| `basic-memory` | Local | — |
| `terraform` | Local | — |
| `qmd` | Remote | URL |
| `deepwiki` | Remote | — |
| `exa` | Remote | — |
| `openrouter-search` | Mixed | API key or env var |

```nix
programs.ai-tools.mcp = {
  servers = {
    sequential-thinking.enable = true;
    git.enable = true;
    memory.enable = true;
    serena.enable = true;
    filesystem.enable = true;
  };
  filesystem.allowedPaths = [ "/home/user" "/work/project" ];
  memoryBaseDir = "/home/user/.cache/ai-tools";
};
```

Override or replace servers without editing this repo:

```nix
programs.ai-tools.mcp = {
  servers.deepwiki.enable = true;
  serverOverrides.deepwiki.url = "https://custom-deepwiki.example.com/mcp";
  extraServers.my-tool = {
    command = "/path/to/my-mcp";
    args = [ "--stdio" ];
  };
};
```

Each agent controls whether it inherits from global MCP defaults:

```nix
# All agents inherit (default).
programs.ai-tools.tools.opencode.mcp.inheritGlobal = true;   # or false
# Per-profile override:
programs.ai-tools.tools.opencode.profiles.work.mcp.inheritGlobal = false;
```

Secrets stay outside Nix — use `apiKeyFile` or environment variables:

```nix
programs.ai-tools.mcp.servers.openrouter-search = {
  enable = true;
  apiKeyFile = "/run/secrets/openrouter-api-key";
};
```

## Skills

40 bundled skills, discovered by all four agents:

| Skill | Description |
|-------|-------------|
| Base (6) | agent-browser, dcp, basic-memory, notebooklm, rtk, karpathy-guidelines |
| Caveman variants (7) | caveman, caveman-commit, caveman-review, caveman-help, caveman-compress, caveman-stats, cavecrew |
| Matt Pocock (13) | diagnose, grill-with-docs, triage, improve-codebase-architecture, setup-matt-pocock-skills, tdd, to-issues, to-prd, zoom-out, prototype, grill-me, handoff, write-a-skill |
| Superpowers (14) | brainstorming, dispatching-parallel-agents, executing-plans, finishing-a-development-branch, receiving-code-review, requesting-code-review, subagent-driven-development, systematic-debugging, test-driven-development, using-git-worktrees, using-superpowers, verification-before-completion, writing-plans, writing-skills |

## Commands

22 bundled slash commands:

**Nix** — `refactor`, `flake-update`, `module-scaffold`, `option-migrate`, `template-new`, `nix-check`

**Git** — `add-and-format`, `review`, `commit-msg`, `commit-changes`

**Quality** — `quick-check`, `deep-check`, `style-audit`, `dependency-audit`, `module-lint`

**Project** — `changelog`

**PRD** — `create-prds`, `generate-tasks`, `process-task-list`

**Caveman** — `caveman`, `caveman-commit`, `caveman-review`

## Agents

8 specialized sub-agents:

**General** — `code-reviewer`, `documenter`, `security-auditor`

**Nix** — `nix-expert`, `flake-expert`, `module-expert`

**Project** — `template-designer`, `system-config-expert`

## OpenCode Profiles

Multi-profile support for isolated OpenCode configs:

```nix
programs.ai-tools.tools.opencode = {
  enable = true;
  theme = "catppuccin";

  lsp = {
    nixd.enable = true;
    pyright.enable = true;
  };

  dcp = {
    enable = true;
    settings.compress.minContextLimit = 60000;
  };

  rtk = {
    enable = true;
    excludeCommands = [ "curl" ];
    tee = { enable = true; mode = "failures"; };
  };

  profiles.work = {
    commandName = "ocw";
    configDir = ".config/opencode-work";
    theme = "nightowl";
    mcp.memoryDir = "opencode-work";
  };
};
```

Each profile gets: isolated config dir, wrapper script, per-profile MCP config, DCP/RTK settings, and optional `dataDir`/`stateDir` isolation.

## omp (oh-my-pi)

Terminal-based coding agent with multi-provider support. Config generation includes `config.yml`, `models.yml`, MCP servers, agents, commands, skills, and TypeScript hooks.

```nix
programs.ai-tools.tools.omp = {
  enable = true;

  env = {
    ANTHROPIC_API_KEY = "...";
  };

  # Runtime secret files are read by the wrapper without copying secrets into
  # the Nix store. Literal `env` values stay shell-safe and are not evaluated.
  envFiles = {
    OLLAMA_CLOUD_API_KEY = "/run/secrets/ollama-cloud-api-key";
    OPENROUTER_API_KEY = "/run/secrets/openrouter-api-key";
    OPENCODE_API_KEY = "/run/secrets/opencode-api-key";
  };

  # OMP reads model routing from config.yml.
  settings = {
    modelRoles.default = "ollama-cloud/glm-5.1";
    modelRoles.plan = "openai-codex/gpt-5.5";
    enabledModels = [
      "ollama-cloud/glm-5.1"
      "openai-codex/gpt-5.5"
      "openrouter/anthropic/claude-sonnet-4.5"
    ];
    modelProviderOrder = [
      "ollama-cloud"
      "opencode"
      "openai-codex"
      "openrouter"
    ];
    disabledProviders = [ ];
    retry = {
      enabled = true;
      maxRetries = 3;
    };
  };

  # models.yml is reserved for provider registry data and equivalence/custom
  # model definitions.
  modelSettings.providers = { };

  hooks = {
    permissionGate = {
      enable = true;        # default: true
      mode = "ask";         # "ask" prompts; "block" denies without prompting
      # Defaults include destructive shell patterns plus publish/deploy/delete
      # commands for git, Docker, Terraform, Kubernetes, AWS, GCP, dbt, and npm/yarn/pnpm.
      extraBlockedCommands = [ "systemctl" ];
      extraBlockedPatterns = [
        {
          pattern = "\\bnix-collect-garbage\\b";
          flags = "";
        }
      ];
      # To replace the defaults instead of appending:
      # blockedCommands = [ "reboot" ];
      # blockedPatterns = [ ];
    };
    protectedPaths = {
      enable = true;        # default: true
      mode = "ask";         # "ask" prompts; "block" denies without prompting
      protectReads = true;  # also ask/block on read/find/search, not just writes
      # Defaults include .env, .env.*, .git/**, node_modules/**, .direnv/**,
      # .devenv/**, and .omp/**. Append more protected paths:
      extraGlobs = [ "secrets/**" ];
      # To replace the defaults instead of appending:
      # globs = [ "secrets/**" ];
    };
    pathAccess = {
      enable = true;        # default: true
      mode = "ask";         # "ask", "block", or "allow"
      # Both lists accept absolute paths or ~ (expanded to $HOME).
      allowPaths = [ "/nix/store" ];
      denyPaths = [ "~/.ssh" "~/.gnupg" ];
    };
    custom.audit-log = ''
      export default function (pi) {
        pi.on("tool_call", function (call) {
          console.error("[audit]", call.toolName)
        })
      }
    '';
  };

  mcp.servers = {
    git.enable = true;
    memory.enable = true;
  };

  compaction = {
    enabled = true;
    strategy = "context-full";
  };

  profiles.work = {
    commandName = "ompw";
    configDir = ".omp-work";
    env.ANTHROPIC_API_KEY = "...";
  };
};
```

Default guardrail lists are defined in [`lib/omp.nix`](./lib/omp.nix): `defaultPermissionGateBlockedPatterns` / `defaultPermissionGateBlockedCommands`, `defaultProtectedPathGlobs`, and `defaultPathAccessAllowPaths` / `defaultPathAccessDenyPaths`.

**Note:** omp's `agent.db` (OAuth tokens set via `/login`) is not Nix-managed. Run `/login` once per profile after initial setup.

## LSP Support (OpenCode)

Bash, Python, Nix, Terraform, Go, YAML, JSON language servers — all configured from Nix packages:

```nix
programs.ai-tools.tools.opencode.lsp = {
  bashls.enable = true;
  pyright.enable = true;
  nixd.enable = true;
  terraformls.enable = false;
  gopls.enable = true;
  yamlls.enable = true;
  jsonls.enable = true;
};
```

Wire `nixd` to your NixOS config for option completions:

```nix
programs.ai-tools.nixos = {
  flakePath = "/home/user/nix-config";
  configurationName = "workstation";
};
```

## Dev Shell Integration

### Scaffolding

```bash
nix flake init -t github:zolszabo/ai-tools#local-dev
nix develop
```

The dev shell creates a project-local AI home under `.ai-tools/home/` — no system changes needed.

### flake-parts

```nix
{
  imports = [ ai-tools.flakeModules.default ];
  perSystem = { ... }: {
    ai-tools.devshells.default = {
      aiTools = {
        mcp.servers.git.enable = true;
        tools.opencode.enable = true;
      };
      extraPackages = [ pkgs.ripgrep ];
    };
  };
}
```

### Plain flake

```nix
devShells.${system}.default = ai-tools.lib.mkAiToolsDevShell {
  inherit pkgs;
  aiTools = {
    mcp.servers.git.enable = true;
    tools.opencode.enable = true;
  };
  extraPackages = [ pkgs.ripgrep ];
};
```

## NixOS Module

Wrap the HM module for system-wide use:

```nix
{
  imports = [ ai-tools.nixosModules.default ];
  home-manager.users.alice.programs.ai-tools = {
    enable = true;
    tools.opencode.enable = true;
  };
}
```

## Flake Outputs

| Output | Description |
|--------|-------------|
| `homeManagerModules.default` | Core HM module |
| `nixosModules.default` | NixOS wrapper |
| `flakeModules.default` | flake-parts devshell module |
| `packages.<system>.default` | All-in-one bundle |
| `packages.<system>.claude-code` | Claude Code binary |
| `packages.<system>.codex` | Codex binary |
| `packages.<system>.opencode` | OpenCode binary |
| `packages.<system>.omp` | omp (oh-my-pi) binary |
| `packages.<system>.mcp` | MCP runtime bundle |
| `lib.mkAiToolsDevShell` | Dev shell builder |
| `templates.local-dev` | Quick-start template |

## Binary Caches

```
https://cache.numtide.com
https://ai-tools.cachix.org
```

Consumers get cache hits automatically when trusting this flake's config. Or add manually:

```nix
nix.settings = {
  substituters = [ "https://ai-tools.cachix.org" ];
  trusted-public-keys = [ "ai-tools.cachix.org-1:4hlOyu6MVh7DhTl3dG4u1zlyhD834yElTL8bnPu4z2M=" ];
};
```

## Releasing

```bash
./scripts/release.sh 0.2.0
```

Bumps version in `flake.nix`, commits, tags, and pushes. GitHub Actions builds and publishes to Cachix, creates GitHub release with changelog from `git-cliff`.

Flake inputs update weekly via automated PRs from `.github/workflows/update-flake-inputs.yml`.
