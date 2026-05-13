# local-dev template

A minimal starting point for a project or personal flake that pulls in `ai-tools` either as
a `nix develop` dev shell or as a Home Manager module.

## Quick start

```bash
# Copy the template into your project
nix flake init -t github:zolszabo/ai-tools#local-dev

# Enter the dev shell (project-local AI home, no system changes)
nix develop

# Or apply via Home Manager (requires home-manager on PATH)
home-manager switch --flake .#dev
```

## How it works

### `nix develop`

Entering the dev shell generates project-local configuration files under
`.ai-tools/home/` inside your project directory. The AI tools (`claude`, `codex`, `opencode`)
are available in PATH and use that directory as their `HOME`, so they do not touch your real
user home or any system-level config.

On each `nix develop` entry the config is regenerated from the flake definition, so you get
reproducible, version-controlled AI settings.

### Home Manager (`homeConfigurations.dev`)

The `homeConfigurations.dev` output applies the `ai-tools` Home Manager module to a real user
account. This permanently installs the AI tools and writes config files to `$HOME`.

Replace the placeholder values in `flake.nix`:
```nix
home.username = "your-username";
home.homeDirectory = "/home/your-username"; # or /Users/your-username on macOS
```

## Customising

All options are documented in the [ai-tools README](https://github.com/zolszabo/ai-tools#readme).

### Enable additional MCP servers

```nix
programs.ai-tools.mcp.servers = {
  context7.enable = true;
  nixos.enable = true;
  deepwiki.enable = true;
};
```

### Change the AI model

```nix
programs.ai-tools.tools.opencode.model = "anthropic/claude-opus-4-5";
programs.ai-tools.tools.claudeCode.model = "claude-opus-4-5";
```

### Disable LSPs you don't need

```nix
programs.ai-tools.tools.opencode.lsp = {
  terraformls.enable = false;
  gopls.enable = false;
};
```

### Tune OpenCode defaults

```nix
programs.ai-tools.tools.opencode = {
  theme = "dark";
  smallModel = "openrouter/google/gemini-flash-1.5";
  disabledProviders = []; # allow all providers
};
```

### Add extra secrets or environment variables

Use `programs.ai-tools.mcp.servers.openrouter-search` to wire an API key:

```nix
programs.ai-tools.mcp.servers.openrouter-search = {
  enable = true;
  apiKeyFile = "/run/secrets/openrouter-api-key"; # managed by sops-nix, agenix, etc.
};
```

## System support

The template auto-detects your machine's system via `builtins.currentSystem`. This covers:
- `x86_64-linux`
- `aarch64-linux`
- `x86_64-darwin`
- `aarch64-darwin`
