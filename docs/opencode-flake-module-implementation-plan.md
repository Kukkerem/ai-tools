# OpenCode Flake Module Implementation Plan

## Goal

Make this repo a reusable baseline OpenCode setup for colleagues through the existing Home Manager flake module.

The module should provide switchable tools, skills, commands, agents, MCP servers, and sensible OpenCode defaults with user override points. It should not move or reproduce the personal multi-profile setup from `/home/zolszabo/nix-config/home/zolszabo/features/cli/ai`.

## Success Criteria

- `programs.ai-tools.enable = true` produces a usable baseline setup.
- OpenCode, Claude Code, and Codex remain independently switchable.
- Skills, commands, and agents from the nix-config setup are available from this repo.
- MCP servers are individually switchable.
- Default MCP/OpenCode settings can be overridden without editing this repo.
- No hardcoded personal paths, SOPS secrets, work profile logic, or `/home/zolszabo` assumptions remain in reusable code.
- `nix flake check` passes.
- README documents the new options accurately.

## Current Baseline

This repo already has:

- Flake outputs in `flake.nix`.
- Home Manager module at `modules/home-manager/ai-tools.nix`.
- Shared AI assets under `ai-tools/`.
- Basic MCP abstraction in `lib/mcp.nix`.
- Package grouping in `lib/packages.nix`.
- Passing baseline check with `nix flake check`.

Existing repo MCP toggles:

- `sequentialThinking`
- `git`
- `nixos`
- `time`
- `memory`
- `serena`
- `playwright`
- `filesystem`

Reusable source setup to compare against:

- `/home/zolszabo/nix-config/home/zolszabo/features/cli/ai`

## Keep Out Of Scope

Do not copy these from nix-config:

- Multi-profile wrapper entrypoints.
- Personal OpenCode profile launchers.
- Hardcoded home paths like `/home/zolszabo`.
- SOPS secret paths.
- Work/personal OpenRouter secret selection logic.
- Personal Basic Memory project path.
- OpenClaw-specific NotebookLM gateway instructions unless converted to generic guidance.

## Implementation Steps

### 1. Copy Missing AI Assets

Add reusable missing skills from nix-config into this repo:

- `ai-tools/skills/caveman/index.nix`
- `ai-tools/skills/dcp/index.nix`
- `ai-tools/skills/basic-memory/index.nix`
- `ai-tools/skills/notebooklm/index.nix`
- `ai-tools/skills/rtk/index.nix`
- `ai-tools/skills/karpathy-guidelines/index.nix`

Add missing commands:

- `ai-tools/commands/caveman/index.nix`

Update imports:

- `ai-tools/skills.nix`
- `ai-tools/commands.nix`
- `ai-tools/default.nix` if additional args are needed.

Expected changes:

- Add a `caveman` flake input with `flake = false` if caveman skills/commands are sourced from upstream.
- Thread `inputs` through AI asset imports where needed.
- Prefer generic inline skill text when upstream coupling is unnecessary.

Verify:

```bash
nix eval .#checks.x86_64-linux.default.drvPath
nix eval --impure --expr 'let f = builtins.getFlake "git+file:///home/zolszabo/workspace/private/ai-tools"; in builtins.attrNames ((import "${f}/ai-tools" { inherit (f.inputs.nixpkgs.legacyPackages.x86_64-linux) lib; pkgs = f.inputs.nixpkgs.legacyPackages.x86_64-linux; }).claudeCode.skills)'
```

Use a simpler equivalent `nix eval` if this expression becomes awkward.

### 2. Extract Reusable OpenCode Defaults

Create a small reusable helper, likely one of:

- `lib/opencode.nix`
- `lib/opencode-defaults.nix`

Move reusable defaults from nix-config `shared/opencode-defaults.nix`:

- `share = "manual"`
- `autoshare = false`
- `autoupdate = true`
- `disabled_providers = [ "github-copilot" ]`
- `small_model = "openrouter/openai/gpt-5-nano"`
- default permissions:
  - `bash = "ask"`
  - `edit = "ask"`
  - `webfetch = "allow"`
- `nixfmt` formatter config.

Add module options:

```nix
programs.ai-tools.tools.opencode.settings
programs.ai-tools.tools.opencode.extraSettings
programs.ai-tools.tools.opencode.plugins
programs.ai-tools.tools.opencode.permission
```

Use whichever option shape fits the current module best, but keep it minimal. Prefer a single `settings` override attrset if that is enough.

Verify:

```bash
nix eval .#checks.x86_64-linux.default.drvPath
```

### 3. Add Optional DCP And RTK Support

Reusable pieces from nix-config `shared/opencode-profile.nix`:

- `dcpConfig`
- `rtkPlugin`
- `rtkPackage` wrapper with `LC_ALL=C`

Add module options:

```nix
programs.ai-tools.tools.opencode.dcp.enable
programs.ai-tools.tools.opencode.rtk.enable
```

Suggested defaults:

- `dcp.enable = true` because this is a baseline quality improvement for OpenCode.
- `rtk.enable = true` only if the required package is already available from `llm-agents`; otherwise make it disabled by default.

Generated files when enabled:

- `.config/opencode/dcp.jsonc`
- `.config/opencode/plugins/rtk.ts`
- `.config/rtk/config.toml`

Add plugins when enabled:

- `@tarquinen/opencode-dcp@latest`

Do not copy profile wrappers that set `OPENCODE_CONFIG` or `OPENCODE_CONFIG_DIR`.

Verify:

```bash
nix flake check
```

### 4. Expand MCP Registry

Enhance `lib/mcp.nix` to support reusable MCP servers from nix-config.

Add safe/local or low-friction MCPs:

- `context7`
- `fetch`
- `notebooklm`
- `basic-memory`
- `terraform`

Add optional remote/API MCPs as disabled-by-default:

- `qmd`
- `cloudflare-docs`
- `deepwiki`
- `exa`
- `openrouter-search`
- `hetzner`
- `tailscale`

Do not hardcode secrets. Model secrets as options, for example:

```nix
programs.ai-tools.mcp.servers.openrouterSearch.apiKeyFile = null;
programs.ai-tools.mcp.servers.hetzner.env.HCLOUD_TOKEN = "${HCLOUD_TOKEN}";
programs.ai-tools.mcp.servers.tailscale.env.TAILSCALE_API_KEY = "${TAILSCALE_API_KEY}";
programs.ai-tools.mcp.servers.tailscale.env.TAILSCALE_TAILNET = "${TAILSCALE_TAILNET}";
```

Prefer generic override options over many one-off options:

```nix
programs.ai-tools.mcp.serverOverrides
programs.ai-tools.mcp.extraServers
```

Server conversion must preserve current output formats:

- Claude Code local server: `{ type = "stdio"; command = ...; }`
- Claude Code remote server: `{ type = "http"; url = ...; }`
- OpenCode local server: `{ type = "local"; enabled = true; command = [ ... ]; }`
- OpenCode remote server: `{ type = "remote"; enabled = true; url = ...; }`
- Codex local server: `{ command = ...; }`
- Codex remote server: `{ serverUrl = ...; }`

Verify:

```bash
nix eval .#checks.x86_64-linux.default.drvPath
```

Add targeted eval checks for at least one local and one remote MCP if practical.

### 5. Package Support

Update `lib/packages.nix` for runtime packages required by new optional MCPs.

Known package notes:

- `context7-mcp` exists in `mcp-servers-nix`.
- `mcp-server-fetch` exists in `mcp-servers-nix`; nix-config patches it for `httpx` compatibility.
- `terraform-mcp-server` exists in nixpkgs unstable as version `0.5.0`; nix-config has custom `0.5.2` packaging.
- `notebooklm` is not in nixpkgs; nix-config wraps `uv tool run notebooklm-mcp-cli==0.6.3`.
- `basic-memory` is not in nixpkgs; nix-config has a custom package. Decide whether to copy packaging or wrap via `uv`.

Preferred implementation:

- Use nixpkgs packages where available.
- Use small `writeShellScriptBin` wrappers for MCPs that are CLI-only and low-risk.
- Avoid copying large custom package expressions unless the wrapper is insufficient.

Verify:

```bash
nix build .#mcp
```

### 6. Add Override Tests In The Existing Check

Extend `flake.nix` `checks.default` with representative config:

- Enable current default MCPs.
- Enable one new local MCP, such as `context7` or `fetch`.
- Enable one remote MCP, such as `deepwiki`, if remote config does not require secrets.
- Add a small `serverOverrides` example.
- Add a small `extraServers` example.

Keep the check evaluation-only unless build-time confidence is required.

Verify:

```bash
nix flake check
```

### 7. Update Documentation

Update `README.md` with:

- New skill list or a short statement that skills are bundled from `ai-tools/skills`.
- Full MCP toggle list.
- OpenCode override example.
- MCP override example.
- Secret/API-key guidance.

Example override shape to document:

```nix
programs.ai-tools = {
  enable = true;

  tools.opencode.settings = {
    theme = "catppuccin";
    small_model = "openrouter/openai/gpt-5-nano";
  };

  mcp = {
    servers = {
      context7.enable = true;
      deepwiki.enable = true;
      filesystem.enable = true;
    };

    filesystem.allowedPaths = [
      "${config.home.homeDirectory}"
      "/work/project"
    ];

    serverOverrides.deepwiki = {
      url = "https://mcp.deepwiki.com/mcp";
    };
  };
}
```

Verify docs manually against actual option names before finalizing.

## Suggested Implementation Order

1. Add missing skills and commands.
2. Add reusable OpenCode defaults/options.
3. Add DCP/RTK optional support.
4. Expand MCP registry with local/remote support and overrides.
5. Update package set.
6. Extend flake checks.
7. Update README.
8. Run final verification.

## Final Verification Checklist

Run from repo root:

```bash
nix fmt
nix flake check
nix build .#default
nix build .#mcp
```

Inspect generated Home Manager config if needed:

```bash
nix build .#checks.x86_64-linux.default
```

Confirm no personal paths leaked:

```bash
rg '/home/zolszabo|sops|openrouter-work|Obsidian Vault' .
```

Only intentional references in this document should remain.

## Notes For Future Implementation

- Keep each option addition tied to a real copied feature.
- Prefer one generic override attrset over many special-case knobs.
- Keep new defaults conservative and colleague-safe.
- If an MCP requires credentials, default it to disabled.
- If an MCP is remote but credential-free, it can still default to disabled to avoid surprising external calls.
- Preserve existing generated config formats for Claude Code, Codex, and OpenCode.
