{
  description = "Example standalone Home Manager configuration using ai-tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ai-tools.url = "github:Kukkerem/ai-tools";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      ai-tools,
      ...
    }:
    let
      # Detect the current machine's system. Override with a literal
      # (e.g. "aarch64-darwin") if you build for another arch.
      system = builtins.currentSystem;
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true; # claude-code / codex are unfree
      };
    in
    {
      # Apply with: home-manager switch --flake .#example
      homeConfigurations.example = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ai-tools.homeManagerModules.default
          (
            { ... }:
            {
              # Replace with your real account.
              home.username = "alice";
              home.homeDirectory = "/home/alice";
              home.stateVersion = "25.05";

              programs.ai-tools = {
                enable = true;

                # Opt-in shared system prompt. Empty by default → no context is
                # injected and each tool keeps its own defaults. Point at your own:
                # instructions = builtins.readFile ./system-prompt.md;

                # ── Skills ────────────────────────────────────────────────
                # Bundled skill groups are on by default; opt individual
                # groups out here.
                skills.agentBrowser.enable = false; # skip if you manage chromium elsewhere
                skills.terraform.enable = true;
                skills.gog.enable = true;
                skills.mattpocock.enable = false;

                # ── nixd option completion ────────────────────────────────
                # Point nixd at your NixOS flake for option completion. (Only
                # nixd uses this; the `nixos` MCP server below takes no config.)
                nixos = {
                  flakePath = "/home/alice/nix-config";
                  configurationName = "workstation";
                };

                # ── The four agents — enable only what you use ────────────
                tools = {
                  claudeCode = {
                    enable = true;
                    model = "claude-sonnet-4-6";
                    settings.permission.allow = [
                      "WebFetch(domain:github.com)"
                      "mcp__github__get_file_contents"
                    ];
                  };

                  codex = {
                    enable = true;
                    model = "gpt-5.5";
                    reasoningEffort = "high";
                  };

                  opencode = {
                    enable = true;
                    theme = "catppuccin";
                    dcp.settings.compress.maxContextLimit = 150000;
                  };

                  # omp (oh-my-pi) is the most configurable agent. The blocks
                  # below show one of each capability; trim to taste.
                  omp = {
                    enable = true;

                    # Secret files are read at runtime by the wrapper; their
                    # values never enter the Nix store. Point these at your
                    # secret manager's outputs, e.g.
                    #   config.sops.secrets.openrouter-api-key.path
                    envFiles = {
                      OPENROUTER_API_KEY = "/run/secrets/openrouter-api-key";
                    };

                    # Built-in local autonomous memory pipeline.
                    memories.enabled = true;

                    # Per-agent MCP set, independent of the global servers below.
                    mcp = {
                      enable = true;
                      inheritGlobal = false;
                      servers = {
                        nixos.enable = true;
                        context7.enable = true;
                        deepwiki.enable = true;
                      };
                      extraServers.cloudflare-docs.url = "https://docs.mcp.cloudflare.com/mcp";
                    };

                    # config.yml — model routing, behaviour, native tools.
                    settings = {
                      symbolPreset = "nerd";
                      theme.dark = "dark-github";
                      defaultThinkingLevel = "high";

                      modelProviderOrder = [ "openrouter" ];
                      enabledModels = [ "openrouter/*" ];
                      modelRoles = {
                        default = "openrouter/anthropic/claude-sonnet-4.5";
                        plan = "openrouter/anthropic/claude-opus-4.1";
                        smol = "openrouter/anthropic/claude-3.5-haiku";
                      };

                      retry = {
                        enabled = true;
                        maxRetries = 3;
                        baseDelayMs = 2000;
                      };

                      compaction = {
                        idleEnabled = true;
                        keepRecentTokens = 30000;
                      };

                      lsp.enabled = true;
                      github.enabled = true;
                      web_search.enabled = true;
                      bashInterceptor.enabled = true;
                    };

                    # TypeScript safety hooks rendered into the omp extensions
                    # dir. "ask" prompts; "block" denies without prompting.
                    hooks = {
                      permissionGate = {
                        enable = true;
                        mode = "ask";
                      };
                      protectedPaths = {
                        enable = true;
                        mode = "ask";
                        protectReads = true;
                        extraGlobs = [ "secrets/**" ];
                      };
                      pathAccess = {
                        mode = "ask";
                        allowPaths = [
                          "/nix/store"
                          "~/.omp"
                        ];
                        denyPaths = [
                          "~/.ssh"
                          "~/.gnupg"
                        ];
                      };
                    };

                    # A second, isolated profile: its own wrapper command and
                    # config dir, with independent model routing and secrets.
                    profiles.work = {
                      enable = true;
                      commandName = "ompwork";
                      configDir = ".omp-work";
                      envFiles.OPENROUTER_API_KEY = "/run/secrets/openrouter-work-api-key";
                      settings = {
                        modelProviderOrder = [ "openrouter" ];
                        enabledModels = [ "openrouter/*" ];
                        modelRoles.default = "openrouter/anthropic/claude-sonnet-4.5";
                        theme.dark = "titanium";
                      };
                      hooks = {
                        permissionGate.enable = true;
                        protectedPaths.enable = true;
                      };
                    };

                    # ── Advanced: custom OpenAI-compatible provider ─────────
                    # Uncomment and adapt to expose models omp has no built-in
                    # catalog for (e.g. Ollama Cloud). modelRoles can then
                    # reference these IDs directly. `apiKey` names an envFiles
                    # key, not a literal secret.
                    #
                    # extraModelSettings.providers.ollama-cloud = {
                    #   baseUrl = "https://ollama.com/v1";
                    #   api = "openai-completions";
                    #   apiKey = "OLLAMA_CLOUD_API_KEY";
                    #   models = [
                    #     {
                    #       id = "deepseek-v4-pro:cloud";
                    #       name = "DeepSeek V4 Pro";
                    #       reasoning = true;
                    #       input = [ "text" ];
                    #       contextWindow = 1048576;
                    #       maxTokens = 65536;
                    #     }
                    #   ];
                    # };
                  };
                };

                # ── Global MCP servers ────────────────────────────────────
                # Shared by every agent that inherits global defaults. All
                # servers are disabled by default; enable only what you need.
                mcp = {
                  servers = {
                    context7.enable = true;
                    nixos.enable = true;
                    deepwiki.enable = true;
                  };
                  extraServers.cloudflare-docs.url = "https://docs.mcp.cloudflare.com/mcp";
                };
              };
            }
          )
        ];
      };
    };
}
