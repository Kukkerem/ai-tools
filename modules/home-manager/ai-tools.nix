{ inputs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.ai-tools;

  inherit (lib)
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    optional
    optionals
    types
    ;

  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  aiTools = import ../../ai-tools { inherit lib pkgs; };
  mcp = import ../../lib/mcp.nix { inherit inputs lib pkgs; };
  packageSets = import ../../lib/packages.nix { inherit inputs lib pkgs; };

  mkServerOption = description: default: {
    enable = mkEnableOption description // {
      inherit default;
    };
  };

  enabledMcpServerNames =
    optionals cfg.mcp.servers.sequentialThinking.enable [ "sequential-thinking" ]
    ++ optionals cfg.mcp.servers.git.enable [ "git" ]
    ++ optionals cfg.mcp.servers.nixos.enable [ "nixos" ]
    ++ optionals cfg.mcp.servers.time.enable [ "time" ]
    ++ optionals cfg.mcp.servers.memory.enable [ "memory" ]
    ++ optionals cfg.mcp.servers.serena.enable [ "serena" ]
    ++ optionals cfg.mcp.servers.playwright.enable [ "playwright" ]
    ++ optionals cfg.mcp.servers.filesystem.enable [ "filesystem" ];

  mkToolMcpServers =
    toolName: builder:
    builder {
      enabledServerNames = enabledMcpServerNames;
      filesystemAllowedPaths = cfg.mcp.filesystem.allowedPaths;
      memoryBaseDir = cfg.mcp.memoryBaseDir;
      memoryDir = toolName;
    };

  instructions = builtins.readFile ../../base.md;

  codexTomlFormat = pkgs.formats.toml { };

  codexConfig = {
    model = cfg.tools.codex.model;
    model_reasoning_effort = cfg.tools.codex.reasoningEffort;
    sandbox_mode = cfg.tools.codex.sandboxMode;
    approval_policy = cfg.tools.codex.approvalPolicy;

    tui = {
      alternate_screen = "auto";
      animations = true;
    };

    memories = {
      generate_memories = true;
      use_memories = true;
    };

    analytics.enabled = false;

    mcp_servers = mkToolMcpServers "codex" mcp.forCodex;
  };

  codexHomeFiles = {
    ".codex/config.toml".source = codexTomlFormat.generate "codex-config" codexConfig;
    ".codex/instructions.md".text = instructions;
    ".codex/skills/agent-browser".source = aiTools.codex.skills.agent-browser;
  }
  // lib.mapAttrs' (
    name: prompt: lib.nameValuePair ".codex/prompts/${name}.md" { text = prompt; }
  ) aiTools.codex.prompts
  // lib.mapAttrs' (
    name: skill: lib.nameValuePair ".codex/skills/${name}/SKILL.md" { text = skill.skillMd; }
  ) aiTools.codex.agentSkills
  // lib.mapAttrs' (
    name: skill:
    lib.nameValuePair ".codex/skills/${name}/agents/openai.yaml" { text = skill.openaiYaml; }
  ) aiTools.codex.agentSkills;

  nixdInitialization = {
    formatting.command = [ (lib.getExe pkgs.nixfmt) ];
  }
  // lib.optionalAttrs (cfg.nixos.flakePath != null && cfg.nixos.configurationName != null) {
    options.nixos.expr = ''(builtins.getFlake "${cfg.nixos.flakePath}").nixosConfigurations.${cfg.nixos.configurationName}.options'';
  };

  gitIgnores =
    optional cfg.tools.claudeCode.enable ".claude/"
    ++ optional cfg.tools.codex.enable ".codex/"
    ++ optional cfg.tools.opencode.enable ".opencode/";
in
{
  options.programs.ai-tools = {
    enable = mkEnableOption "shared AI CLI setup";

    profileName = mkOption {
      type = types.str;
      default = "default";
      description = "Profile name used for local AI setup state such as memory files.";
    };

    nixos = {
      flakePath = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional flake path used to expose NixOS options to nixd inside opencode.";
      };

      configurationName = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional NixOS configuration name used with `nixos.flakePath`.";
      };
    };

    tools = {
      claudeCode = {
        enable = mkEnableOption "Claude Code" // {
          default = true;
        };
      };

      codex = {
        enable = mkEnableOption "Codex" // {
          default = true;
        };

        model = mkOption {
          type = types.str;
          default = "gpt-5.4";
          description = "Codex model name.";
        };

        reasoningEffort = mkOption {
          type = types.enum [
            "low"
            "medium"
            "high"
          ];
          default = "high";
          description = "Codex reasoning effort.";
        };

        sandboxMode = mkOption {
          type = types.enum [
            "read-only"
            "workspace-write"
            "danger-full-access"
          ];
          default = "workspace-write";
          description = "Codex sandbox mode.";
        };

        approvalPolicy = mkOption {
          type = types.enum [
            "never"
            "on-failure"
            "untrusted"
            "on-request"
          ];
          default = "untrusted";
          description = "Codex approval policy.";
        };
      };

      opencode = {
        enable = mkEnableOption "OpenCode" // {
          default = true;
        };
      };
    };

    mcp = {
      memoryBaseDir = mkOption {
        type = types.str;
        default = "${config.home.homeDirectory}/.cache/ai-tools";
        description = "Base directory for MCP server state such as memory files.";
      };

      filesystem.allowedPaths = mkOption {
        type = types.listOf types.str;
        default = [ config.home.homeDirectory ];
        description = "Allowed filesystem roots exposed through the filesystem MCP server.";
      };

      servers = {
        sequentialThinking = mkServerOption "the sequential-thinking MCP server" true;
        git = mkServerOption "the git MCP server" true;
        nixos = mkServerOption "the nixos MCP server" false;
        time = mkServerOption "the time MCP server" true;
        memory = mkServerOption "the memory MCP server" true;
        serena = mkServerOption "the serena MCP server" true;
        playwright = mkServerOption "the playwright MCP server" false;
        filesystem = mkServerOption "the filesystem MCP server" true;
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      home.packages = packageSets.sharedAgentPackages;
      programs.git.ignores = lib.mkAfter gitIgnores;
    }

    (mkIf cfg.mcp.servers.serena.enable {
      home.packages = packageSets.serenaSupportPackages;
    })

    (mkIf cfg.tools.claudeCode.enable {
      home.packages = packageSets.claudeCodeHelperPackages;

      programs.claude-code = {
        enable = true;
        package = llmAgents.claude-code;
        mcpServers = mkToolMcpServers "claudecode" mcp.forClaudeCode;
        settings = {
          theme = "dark";
          statusLine = {
            type = "command";
            command = ''input=$(cat); echo "[$(echo "$input" | jq -r '.model.display_name')] 📁 $(basename "$(echo "$input" | jq -r '.workspace.current_dir')")"'';
            padding = 0;
          };
          model = "claude-sonnet-4-6";
          verbose = true;
          includeCoAuthoredBy = false;
          permission = {
            allow = [
              "Bash(git add:*)"
              "Bash(git status)"
              "Bash(git log:*)"
              "Bash(git diff:*)"
              "Bash(git show:*)"
              "Bash(git branch:*)"
              "Bash(git remote:*)"
              "Bash(nix:*)"
              "Bash(ls:*)"
              "Bash(find:*)"
              "Bash(grep:*)"
              "Bash(rg:*)"
              "Bash(cat:*)"
              "Bash(head:*)"
              "Bash(tail:*)"
              "Bash(mkdir:*)"
              "Bash(chmod:*)"
              "Bash(systemctl list-units:*)"
              "Bash(systemctl list-timers:*)"
              "Bash(systemctl status:*)"
              "Bash(journalctl:*)"
              "Bash(dmesg:*)"
              "Bash(env)"
              "Bash(claude --version)"
              "Bash(nh search:*)"
              "Bash(pactl list:*)"
              "Bash(pw-top)"
              "Glob(*)"
              "Grep(*)"
              "LS(*)"
              "Read(*)"
              "Search(*)"
              "Task(*)"
              "TodoWrite(*)"
            ];
            ask = [
              "Bash(git checkout:*)"
              "Bash(git commit:*)"
              "Bash(git merge:*)"
              "Bash(git pull:*)"
              "Bash(git push:*)"
              "Bash(git rebase:*)"
              "Bash(git reset:*)"
              "Bash(git restore:*)"
              "Bash(git stash:*)"
              "Bash(git switch:*)"
              "Bash(cp:*)"
              "Bash(mv:*)"
              "Bash(rm:*)"
              "Bash(systemctl disable:*)"
              "Bash(systemctl enable:*)"
              "Bash(systemctl mask:*)"
              "Bash(systemctl reload:*)"
              "Bash(systemctl restart:*)"
              "Bash(systemctl start:*)"
              "Bash(systemctl stop:*)"
              "Bash(systemctl unmask:*)"
              "Bash(curl:*)"
              "Bash(ping:*)"
              "Bash(rsync:*)"
              "Bash(scp:*)"
              "Bash(ssh:*)"
              "Bash(wget:*)"
              "Bash(nixos-rebuild:*)"
              "Bash(sudo:*)"
              "Bash(kill:*)"
              "Bash(killall:*)"
              "Bash(pkill:*)"
            ];
            deny = [ ];
            defaultMode = "default";
          };
        };
        inherit (aiTools.claudeCode)
          agents
          commands
          skills
          ;
        memory.text = instructions;
      };
    })

    (mkIf cfg.tools.codex.enable {
      home.packages = packageSets.codexHelperPackages;

      home.file = codexHomeFiles;

      programs.codex = {
        enable = true;
        package = llmAgents.codex;
      };
    })

    (mkIf cfg.tools.opencode.enable {
      home.packages = packageSets.opencodeHelperPackages;

      programs.opencode = {
        enable = true;
        package = llmAgents.opencode;
        rules = ''
          ## External File Loading

          CRITICAL: When you encounter a file reference (e.g., @rules/general.md), use your Read tool to load it on a need-to-know basis. They're relevant to the SPECIFIC task at hand.

          Instructions:

          - Do NOT preemptively load all references - use lazy loading based on actual need
          - When loaded, treat content as mandatory instructions that override defaults
          - Follow references recursively when needed
        '';
        settings = {
          plugin = [
            "opencode-antigravity-auth@latest"
            "opencode-claude-auth@latest"
            "opencode-openai-codex-auth@latest"
          ];
          theme = "catppuccin";
          share = "manual";
          autoshare = false;
          autoupdate = true;
          disabled_providers = [ "github-copilot" ];
          formatter.nixfmt = {
            command = [
              (lib.getExe pkgs.nixfmt)
              "$FILE"
            ];
            extensions = [ ".nix" ];
          };
          lsp = {
            bashls = {
              command = [
                (lib.getExe pkgs.bash-language-server)
                "start"
              ];
              extensions = [
                ".sh"
                ".bash"
              ];
            };
            pyright = {
              command = [ (lib.getExe pkgs.pyright) ];
              extensions = [
                ".py"
                ".pyi"
              ];
            };
            nixd = {
              command = [ (lib.getExe pkgs.nixd) ];
              extensions = [ ".nix" ];
              initialization = nixdInitialization;
            };
            terraformls = {
              command = [
                (lib.getExe pkgs.terraform-ls)
                "serve"
              ];
              extensions = [
                ".tf"
                ".tfvars"
              ];
            };
            gopls = {
              command = [ (lib.getExe pkgs.gopls) ];
              extensions = [
                ".go"
                ".mod"
                ".sum"
              ];
            };
            yamlls = {
              command = [
                (lib.getExe pkgs.yaml-language-server)
                "--stdio"
              ];
              extensions = [
                ".yaml"
                ".yml"
              ];
            };
            jsonls = {
              command = [
                (lib.getExe' pkgs.vscode-langservers-extracted "vscode-json-language-server")
                "--stdio"
              ];
              extensions = [
                ".json"
                ".jsonc"
              ];
            };
          };
          small_model = "openrouter/openai/gpt-5-nano";
          mcp = mkToolMcpServers "opencode" mcp.forOpenCode;
          permission = {
            bash = "ask";
            edit = "ask";
            webfetch = "allow";
          };
        };
        inherit (aiTools.claudeCode)
          agents
          commands
          skills
          ;
      };
    })
  ]);
}
