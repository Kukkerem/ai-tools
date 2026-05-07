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
    mkDefault
    mkIf
    mkMerge
    mkOption
    optional
    optionals
    optionalAttrs
    optionalString
    types
    ;

  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  aiTools = import ../../ai-tools { inherit inputs lib pkgs; };
  mcp = import ../../lib/mcp.nix { inherit inputs lib pkgs; };
  opencodeSupport = import ../../lib/opencode.nix { inherit inputs lib pkgs; };
  packageSets = import ../../lib/packages.nix { inherit inputs lib pkgs; };

  mkServerOption = description: default: {
    enable = mkEnableOption description // {
      inherit default;
    };
  };

  mkProgramOption =
    programName:
    mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = ''
        Additional definitions merged into `${programName}`. Use this to configure
        upstream Home Manager options that are not modeled by `programs.ai-tools`.
      '';
    };

  enabledMcpServerNames =
    optionals cfg.mcp.servers.sequentialThinking.enable [ "sequential-thinking" ]
    ++ optionals cfg.mcp.servers.git.enable [ "git" ]
    ++ optionals cfg.mcp.servers.context7.enable [ "context7" ]
    ++ optionals cfg.mcp.servers.nixos.enable [ "nixos" ]
    ++ optionals cfg.mcp.servers.time.enable [ "time" ]
    ++ optionals cfg.mcp.servers.fetch.enable [ "fetch" ]
    ++ optionals cfg.mcp.servers.memory.enable [ "memory" ]
    ++ optionals cfg.mcp.servers.serena.enable [ "serena" ]
    ++ optionals cfg.mcp.servers.playwright.enable [ "playwright" ]
    ++ optionals cfg.mcp.servers.filesystem.enable [ "filesystem" ]
    ++ optionals cfg.mcp.servers.notebooklm.enable [ "notebooklm" ]
    ++ optionals cfg.mcp.servers.basicMemory.enable [ "basic-memory" ]
    ++ optionals cfg.mcp.servers.terraform.enable [ "terraform" ]
    ++ optionals cfg.mcp.servers.qmd.enable [ "qmd" ]
    ++ optionals cfg.mcp.servers.deepwiki.enable [ "deepwiki" ]
    ++ optionals cfg.mcp.servers.exa.enable [ "exa" ]
    ++ optionals cfg.mcp.servers.openrouterSearch.enable [ "openrouter-search" ];

  mkToolMcpServers =
    toolName: builder:
    builder {
      enabledServerNames = enabledMcpServerNames;
      filesystemAllowedPaths = cfg.mcp.filesystem.allowedPaths;
      memoryBaseDir = cfg.mcp.memoryBaseDir;
      memoryDir = "${cfg.profileName}-${toolName}";
      qmdUrl = cfg.mcp.servers.qmd.url;
      openrouterSearchApiKey = cfg.mcp.servers.openrouterSearch.apiKey;
      openrouterSearchApiKeyFile = cfg.mcp.servers.openrouterSearch.apiKeyFile;
      openrouterSearchEnv = cfg.mcp.servers.openrouterSearch.env;
      serverOverrides = cfg.mcp.serverOverrides;
      extraServers = cfg.mcp.extraServers;
    };

  mkOpencodeMcpServers =
    memoryDir:
    mcp.forOpenCode {
      enabledServerNames = enabledMcpServerNames;
      filesystemAllowedPaths = cfg.mcp.filesystem.allowedPaths;
      memoryBaseDir = cfg.mcp.memoryBaseDir;
      inherit memoryDir;
      qmdUrl = cfg.mcp.servers.qmd.url;
      openrouterSearchApiKey = cfg.mcp.servers.openrouterSearch.apiKey;
      openrouterSearchApiKeyFile = cfg.mcp.servers.openrouterSearch.apiKeyFile;
      openrouterSearchEnv = cfg.mcp.servers.openrouterSearch.env;
      serverOverrides = cfg.mcp.serverOverrides;
      extraServers = cfg.mcp.extraServers;
    };

  instructions = builtins.readFile ../../base.md;

  opencodeRules = ''
    ## External File Loading

    CRITICAL: When you encounter a file reference (e.g., @rules/general.md), use your Read tool to load it on a need-to-know basis. They're relevant to the SPECIFIC task at hand.

    Instructions:

    - Do NOT preemptively load all references - use lazy loading based on actual need
    - When loaded, treat content as mandatory instructions that override defaults
    - Follow references recursively when needed
  '';

  jsonFormat = pkgs.formats.json { };

  claudeCodeDefaultSettings = {
    theme = "dark";
    statusLine = {
      type = "command";
      command = ''input=$(cat); echo "[$(echo "$input" | jq -r '.model.display_name')] 📁 $(basename "$(echo "$input" | jq -r '.workspace.current_dir')")"'';
      padding = 0;
    };
    model = cfg.tools.claudeCode.model;
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

  claudeCodeSettings = lib.recursiveUpdate (lib.recursiveUpdate claudeCodeDefaultSettings cfg.tools.claudeCode.settings) cfg.tools.claudeCode.extraSettings;

  codexDefaultSettings = {
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

  codexSettings = lib.recursiveUpdate (lib.recursiveUpdate codexDefaultSettings cfg.tools.codex.settings) cfg.tools.codex.extraSettings;

  codexSkills = {
    agent-browser = aiTools.codex.skills.agent-browser;
  };

  codexHomeFiles =
    lib.mapAttrs' (
      name: prompt: lib.nameValuePair ".codex/prompts/${name}.md" { text = prompt; }
    ) aiTools.codex.prompts
    // lib.mapAttrs' (
      name: skill: lib.nameValuePair ".agents/skills/${name}/SKILL.md" { text = skill.skillMd; }
    ) aiTools.codex.agentSkills
    // lib.mapAttrs' (
      name: skill:
      lib.nameValuePair ".agents/skills/${name}/agents/openai.yaml" { text = skill.openaiYaml; }
    ) aiTools.codex.agentSkills;

  nixdInitialization = {
    formatting.command = [ (lib.getExe pkgs.nixfmt) ];
  }
  // lib.optionalAttrs (cfg.nixos.flakePath != null && cfg.nixos.configurationName != null) {
    options.nixos.expr = ''(builtins.getFlake "${cfg.nixos.flakePath}").nixosConfigurations.${cfg.nixos.configurationName}.options'';
  };

  opencodeAuthPlugins = [
    "opencode-antigravity-auth@latest"
    "opencode-claude-auth@latest"
    "opencode-openai-codex-auth@latest"
  ];

  mkOpencodePlugins =
    profile:
    opencodeAuthPlugins
    ++ profile.plugins
    ++ optional (profile.dcp.enable && profile.dcp.plugin != null) profile.dcp.plugin;

  mkOpencodeDefaultSettings =
    profile:
    opencodeSupport.defaultSettings {
      inherit nixdInitialization;
      plugins = mkOpencodePlugins profile;
      permission = profile.permission;
      theme = profile.theme;
      smallModel = profile.smallModel;
      disabledProviders = profile.disabledProviders;
      lspBashls = profile.lsp.bashls.enable;
      lspPyright = profile.lsp.pyright.enable;
      lspNixd = profile.lsp.nixd.enable;
      lspTerraformls = profile.lsp.terraformls.enable;
      lspGopls = profile.lsp.gopls.enable;
      lspYamlls = profile.lsp.yamlls.enable;
      lspJsonls = profile.lsp.jsonls.enable;
    };

  mkOpencodeGeneratedSettings =
    profile:
    mkOpencodeDefaultSettings profile
    // optionalAttrs profile.mcp.enable {
      mcp = mkOpencodeMcpServers profile.mcp.memoryDir;
    }
    // optionalAttrs (profile.model != null) {
      model = profile.model;
    };

  mkOpencodeSettings =
    profile:
    lib.recursiveUpdate (lib.recursiveUpdate (mkOpencodeGeneratedSettings profile) profile.settings) profile.extraSettings;

  mkOpencodeDcpSettings =
    profile:
    lib.recursiveUpdate (lib.recursiveUpdate opencodeSupport.dcpConfig profile.dcp.settings) profile.dcp.extraSettings;

  mkOpencodeWrapper =
    profile: runMode:
    let
      commandName = if runMode then profile.runCommandName else profile.commandName;
    in
    pkgs.writeShellApplication {
      name = commandName;
      runtimeInputs = [ llmAgents.opencode ] ++ profile.extraRuntimePackages;
      text = ''
        export OPENCODE_CONFIG="$HOME/${profile.configDir}/opencode.jsonc"
        export OPENCODE_CONFIG_DIR="$HOME/${profile.configDir}"
      ''
      + optionalString (profile.dataDir != null) ''
        export XDG_DATA_HOME="$HOME/${profile.dataDir}"
      ''
      + optionalString (profile.stateDir != null) ''
        export XDG_STATE_HOME="$HOME/${profile.stateDir}"
      ''
      + ''
        exec ${lib.getExe llmAgents.opencode} ${optionalString runMode "run "}"$@"
      '';
    };

  mkOpencodeProfileConfigFile = name: profile: {
    "${profile.configDir}/opencode.jsonc" = {
      source = jsonFormat.generate "opencode-${name}" (mkOpencodeSettings profile);
    };
  };

  mkOpencodeProfileFiles =
    name: profile:
    let
      sharedFiles = {
        "${profile.configDir}/AGENTS.md".text = opencodeRules;
      }
      // lib.mapAttrs' (
        agentName: agent: lib.nameValuePair "${profile.configDir}/agent/${agentName}.md" { text = agent; }
      ) aiTools.claudeCode.agents
      // lib.mapAttrs' (
        commandName: command:
        lib.nameValuePair "${profile.configDir}/command/${commandName}.md" { text = command; }
      ) aiTools.claudeCode.commands
      // lib.mapAttrs' (
        skillName: skill:
        lib.nameValuePair "${profile.configDir}/skills/${skillName}/SKILL.md" { text = skill; }
      ) aiTools.claudeCode.skills;
      dcpConfig = optionalAttrs profile.dcp.enable {
        "${profile.configDir}/dcp.jsonc".source = jsonFormat.generate "opencode-${name}-dcp" (
          mkOpencodeDcpSettings profile
        );
      };
      rtkFiles = optionalAttrs profile.rtk.enable {
        "${profile.configDir}/plugins/rtk.ts".text = opencodeSupport.rtkPlugin;
        "${profile.configDir}/rtk/config.toml".text = opencodeSupport.mkRtkConfig {
          excludeCommands = profile.rtk.excludeCommands;
          teeEnable = profile.rtk.tee.enable;
          teeMode = profile.rtk.tee.mode;
          telemetryEnable = profile.rtk.telemetry.enable;
        };
      };
      extraFiles = lib.mapAttrs' (
        path: file: lib.nameValuePair "${profile.configDir}/${path}" file
      ) profile.extraFiles;
    in
    mkOpencodeProfileConfigFile name profile // sharedFiles // dcpConfig // rtkFiles // extraFiles;

  legacyOpencodeProfile = {
    enable = cfg.tools.opencode.enable;
    commandName = "opencode";
    runCommandName = null;
    configDir = ".config/opencode";
    dataDir = null;
    stateDir = null;
    inherit (cfg.tools.opencode)
      settings
      extraSettings
      plugins
      permission
      model
      theme
      smallModel
      disabledProviders
      lsp
      dcp
      rtk
      ;
    mcp = {
      enable = true;
      memoryDir = "${cfg.profileName}-opencode";
    };
    extraFiles = { };
    extraRuntimePackages = [ ];
  };

  opencodeProfiles = lib.mapAttrs (
    name: profile:
    let
      baseProfile =
        if name == "default" then lib.recursiveUpdate legacyOpencodeProfile profile else profile;
    in
    baseProfile
    // {
      commandName =
        if baseProfile.commandName != null then
          baseProfile.commandName
        else if name == "default" then
          legacyOpencodeProfile.commandName
        else
          null;
      configDir =
        if baseProfile.configDir != null then
          baseProfile.configDir
        else if name == "default" then
          legacyOpencodeProfile.configDir
        else
          ".config/opencode-${name}";
      mcp =
        legacyOpencodeProfile.mcp
        // baseProfile.mcp
        // optionalAttrs (baseProfile.mcp.memoryDir == null) {
          memoryDir =
            if name == "default" then
              legacyOpencodeProfile.mcp.memoryDir
            else
              "${cfg.profileName}-opencode-${name}";
        };
    }
  ) ({ default = { }; } // cfg.tools.opencode.profiles);

  enabledOpencodeProfiles = lib.filterAttrs (_: profile: profile.enable) opencodeProfiles;
  defaultOpencodeProfile = opencodeProfiles.default;
  defaultOpencodeEnabled = defaultOpencodeProfile.enable;

  extraOpencodeProfiles = lib.filterAttrs (name: _: name != "default") enabledOpencodeProfiles;

  extraOpencodeHomeFiles = lib.foldlAttrs (
    files: name: profile:
    files // mkOpencodeProfileFiles name profile
  ) { } extraOpencodeProfiles;

  defaultOpencodeCustomFiles =
    optionalAttrs defaultOpencodeEnabled (mkOpencodeProfileConfigFile "default" defaultOpencodeProfile)
    // optionalAttrs (
      defaultOpencodeEnabled && defaultOpencodeProfile.configDir != ".config/opencode"
    ) (mkOpencodeProfileFiles "default" defaultOpencodeProfile);

  extraOpencodePackages =
    lib.mapAttrsToList (_: profile: mkOpencodeWrapper profile false) (
      lib.filterAttrs (_: profile: profile.commandName != null) extraOpencodeProfiles
    )
    ++ lib.mapAttrsToList (_: profile: mkOpencodeWrapper profile true) (
      lib.filterAttrs (_: profile: profile.runCommandName != null) enabledOpencodeProfiles
    );

  opencodeRtkEnabled = lib.any (profile: profile.rtk.enable) (lib.attrValues enabledOpencodeProfiles);

  defaultOpencodePackage =
    if defaultOpencodeProfile.commandName != null then
      mkOpencodeWrapper defaultOpencodeProfile false
    else
      llmAgents.opencode;

  opencodeSettings = mkOpencodeSettings defaultOpencodeProfile;

  opencodeDcpSettings = mkOpencodeDcpSettings defaultOpencodeProfile;

  qmdOverride = cfg.mcp.serverOverrides.qmd or { };
  qmdHasUsableDefinition =
    cfg.mcp.servers.qmd.url != null
    || (qmdOverride ? url && qmdOverride.url != null)
    || (qmdOverride ? command && qmdOverride.command != null);

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

        settings = mkOption {
          type = types.attrsOf types.anything;
          default = { };
          description = "Claude Code settings merged into the module defaults.";
        };

        extraSettings = mkOption {
          type = types.attrsOf types.anything;
          default = { };
          description = "Final Claude Code settings override attrset merged after `settings`.";
        };

        program = mkProgramOption "programs.claude-code";

        model = mkOption {
          type = types.str;
          default = "claude-sonnet-4-6";
          description = "Default Claude Code model identifier.";
        };
      };

      codex = {
        enable = mkEnableOption "Codex" // {
          default = true;
        };

        settings = mkOption {
          type = types.attrsOf types.anything;
          default = { };
          description = "Codex settings merged into the module defaults.";
        };

        extraSettings = mkOption {
          type = types.attrsOf types.anything;
          default = { };
          description = "Final Codex settings override attrset merged after `settings`.";
        };

        program = mkProgramOption "programs.codex";

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

        settings = mkOption {
          type = types.attrsOf types.anything;
          default = { };
          description = "Additional OpenCode settings merged into the module defaults.";
        };

        extraSettings = mkOption {
          type = types.attrsOf types.anything;
          default = { };
          description = "Final OpenCode settings override attrset merged after `settings`.";
        };

        plugins = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Additional OpenCode plugin package names or local plugin references. Authentication plugins are always included by this module.";
        };

        program = mkProgramOption "programs.opencode";

        permission = mkOption {
          type = types.attrsOf types.anything;
          default = { };
          description = "OpenCode permission values merged over the module defaults.";
        };

        model = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Default OpenCode model identifier. When non-null this sets `model` in the
            generated settings, which overrides OpenCode's built-in default. Use the
            full provider/model string (e.g. `"anthropic/claude-sonnet-4-5"`).
            Leave null to rely on OpenCode's own default or set it via `settings.model`.
          '';
        };

        theme = mkOption {
          type = types.str;
          default = "catppuccin";
          description = "OpenCode UI theme name (e.g. \"catppuccin\", \"dark\", \"light\").";
        };

        smallModel = mkOption {
          type = types.str;
          default = "openrouter/openai/gpt-5-nano";
          description = "OpenCode small/cheap model used for background tasks.";
        };

        disabledProviders = mkOption {
          type = types.listOf types.str;
          default = [ "github-copilot" ];
          description = "List of provider IDs disabled in OpenCode.";
        };

        lsp = {
          bashls.enable = mkEnableOption "bash-language-server LSP" // {
            default = true;
          };
          pyright.enable = mkEnableOption "pyright Python LSP" // {
            default = true;
          };
          nixd.enable = mkEnableOption "nixd Nix LSP" // {
            default = true;
          };
          terraformls.enable = mkEnableOption "terraform-ls Terraform LSP" // {
            default = true;
          };
          gopls.enable = mkEnableOption "gopls Go LSP" // {
            default = true;
          };
          yamlls.enable = mkEnableOption "yaml-language-server YAML LSP" // {
            default = true;
          };
          jsonls.enable = mkEnableOption "vscode-json-language-server JSON LSP" // {
            default = true;
          };
        };

        dcp.enable = mkEnableOption "OpenCode Dynamic Context Pruning support" // {
          default = true;
        };

        dcp.plugin = mkOption {
          type = types.nullOr types.str;
          default = "@tarquinen/opencode-dcp@latest";
          description = "OpenCode DCP plugin reference. Set to null to manage the plugin through `tools.opencode.plugins` or `tools.opencode.program` yourself.";
        };

        dcp.settings = mkOption {
          type = types.attrsOf types.anything;
          default = { };
          description = "DCP config merged into the module defaults before writing `.config/opencode/dcp.jsonc`.";
        };

        dcp.extraSettings = mkOption {
          type = types.attrsOf types.anything;
          default = { };
          description = "Final DCP config override attrset merged after `dcp.settings`.";
        };

        rtk.enable = mkEnableOption "RTK OpenCode shell-output compression support" // {
          default = true;
          description = ''
            Enable RTK shell-output compression for OpenCode. When enabled, the `rtk`
            binary (from `llm-agents`) is added to `home.packages`, the OpenCode plugin
            is written to `.config/opencode/plugins/rtk.ts`, and the RTK config is
            written to `.config/rtk/config.toml`.
          '';
        };

        rtk.excludeCommands = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = ''
            List of command prefixes that RTK will not intercept. Add commands here
            when you want raw output rather than RTK-compressed output.
          '';
          example = [
            "curl"
            "cat"
          ];
        };

        rtk.tee.enable = mkOption {
          type = types.bool;
          default = true;
          description = "Log command output to a tee file for debugging.";
        };

        rtk.tee.mode = mkOption {
          type = types.str;
          default = "failures";
          description = ''
            Tee logging mode. `"failures"` logs only failed commands; `"all"` logs everything.
          '';
        };

        rtk.telemetry.enable = mkOption {
          type = types.bool;
          default = false;
          description = "Send anonymous usage telemetry to the RTK project.";
        };

        profiles = mkOption {
          type = types.attrsOf (
            types.submodule (
              { name, ... }:
              {
                options = {
                  enable = mkEnableOption "OpenCode profile `${name}`" // {
                    default = true;
                  };

                  commandName = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = ''
                      Wrapper command name for this profile. Set to null to avoid
                      generating a command wrapper for the profile.
                    '';
                  };

                  runCommandName = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Optional wrapper command that executes `opencode run` for this profile.";
                  };

                  configDir = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = ''
                      Home-relative OpenCode config directory. Defaults to
                      `.config/opencode` for the default profile and
                      `.config/opencode-<profile>` for additional profiles.
                    '';
                  };

                  dataDir = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Optional home-relative XDG_DATA_HOME exported by this profile wrapper.";
                  };

                  stateDir = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Optional home-relative XDG_STATE_HOME exported by this profile wrapper.";
                  };

                  settings = mkOption {
                    type = types.attrsOf types.anything;
                    default = { };
                    description = "OpenCode settings merged into the generated profile config.";
                  };

                  extraSettings = mkOption {
                    type = types.attrsOf types.anything;
                    default = { };
                    description = "Final OpenCode settings override attrset merged after `settings`.";
                  };

                  plugins = mkOption {
                    type = types.listOf types.str;
                    default = [ ];
                    description = "Additional OpenCode plugins for this profile.";
                  };

                  extraFiles = mkOption {
                    type = types.attrsOf types.anything;
                    default = { };
                    description = "Extra Home Manager `home.file` entries written under this profile's config directory.";
                  };

                  extraRuntimePackages = mkOption {
                    type = types.listOf types.package;
                    default = [ ];
                    description = "Extra packages added to this profile wrapper runtime PATH.";
                  };

                  permission = mkOption {
                    type = types.attrsOf types.anything;
                    default = { };
                    description = "OpenCode permission values merged over the module defaults for this profile.";
                  };

                  model = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Optional default OpenCode model identifier for this profile.";
                  };

                  theme = mkOption {
                    type = types.str;
                    default = "catppuccin";
                    description = "OpenCode UI theme for this profile.";
                  };

                  smallModel = mkOption {
                    type = types.str;
                    default = "openrouter/openai/gpt-5-nano";
                    description = "OpenCode small/cheap model for this profile.";
                  };

                  disabledProviders = mkOption {
                    type = types.listOf types.str;
                    default = [ "github-copilot" ];
                    description = "Provider IDs disabled in this OpenCode profile.";
                  };

                  lsp = {
                    bashls.enable = mkEnableOption "bash-language-server LSP" // {
                      default = true;
                    };
                    pyright.enable = mkEnableOption "pyright Python LSP" // {
                      default = true;
                    };
                    nixd.enable = mkEnableOption "nixd Nix LSP" // {
                      default = true;
                    };
                    terraformls.enable = mkEnableOption "terraform-ls Terraform LSP" // {
                      default = true;
                    };
                    gopls.enable = mkEnableOption "gopls Go LSP" // {
                      default = true;
                    };
                    yamlls.enable = mkEnableOption "yaml-language-server YAML LSP" // {
                      default = true;
                    };
                    jsonls.enable = mkEnableOption "vscode-json-language-server JSON LSP" // {
                      default = true;
                    };
                  };

                  dcp = {
                    enable = mkEnableOption "OpenCode DCP support for this profile" // {
                      default = true;
                    };
                    plugin = mkOption {
                      type = types.nullOr types.str;
                      default = "@tarquinen/opencode-dcp@latest";
                      description = "OpenCode DCP plugin reference for this profile.";
                    };
                    settings = mkOption {
                      type = types.attrsOf types.anything;
                      default = { };
                      description = "DCP config merged into the module defaults for this profile.";
                    };
                    extraSettings = mkOption {
                      type = types.attrsOf types.anything;
                      default = { };
                      description = "Final DCP config override attrset merged after `dcp.settings`.";
                    };
                  };

                  rtk = {
                    enable = mkEnableOption "RTK support for this profile" // {
                      default = true;
                    };
                    excludeCommands = mkOption {
                      type = types.listOf types.str;
                      default = [ ];
                      description = "Command prefixes that RTK will not intercept for this profile.";
                    };
                    tee.enable = mkOption {
                      type = types.bool;
                      default = true;
                      description = "Log command output to a tee file for debugging.";
                    };
                    tee.mode = mkOption {
                      type = types.str;
                      default = "failures";
                      description = ''
                        Tee logging mode. `"failures"` logs only failed commands;
                        `"all"` logs everything.
                      '';
                    };
                    telemetry.enable = mkOption {
                      type = types.bool;
                      default = false;
                      description = "Send anonymous usage telemetry to the RTK project.";
                    };
                  };

                  mcp = {
                    enable = mkEnableOption "generated MCP server config for this profile" // {
                      default = true;
                    };
                    memoryDir = mkOption {
                      type = types.nullOr types.str;
                      default = null;
                      description = "MCP memory directory name for this profile.";
                    };
                  };
                };
              }
            )
          );
          default = { };
          description = ''
            Additional OpenCode profiles. The existing top-level OpenCode options
            are normalized into `profiles.default` for backwards compatibility.
          '';
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

      serverOverrides = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Raw MCP server definition overrides keyed by generated MCP server name.";
      };

      extraServers = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Additional raw MCP server definitions keyed by generated MCP server name.";
      };

      servers = {
        sequentialThinking = mkServerOption "the sequential-thinking MCP server" true;
        git = mkServerOption "the git MCP server" true;
        context7 = mkServerOption "the Context7 MCP server" false;
        nixos = mkServerOption "the nixos MCP server" false;
        time = mkServerOption "the time MCP server" true;
        fetch = mkServerOption "the fetch MCP server" false;
        memory = mkServerOption "the memory MCP server" true;
        serena = mkServerOption "the serena MCP server" true;
        playwright = mkServerOption "the playwright MCP server" false;
        filesystem = mkServerOption "the filesystem MCP server" true;
        notebooklm = mkServerOption "the NotebookLM MCP server" false;
        basicMemory = mkServerOption "the Basic Memory MCP server" false;
        terraform = mkServerOption "the Terraform MCP server" false;
        qmd = mkServerOption "a QMD remote MCP server" false // {
          url = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Remote QMD MCP URL. Required when enabling QMD unless supplied via `mcp.serverOverrides.qmd.url`.";
          };
        };
        deepwiki = mkServerOption "the DeepWiki remote MCP server" false;
        exa = mkServerOption "the Exa remote MCP server" false;
        openrouterSearch = mkServerOption "the OpenRouter Search MCP server" false // {
          apiKey = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Optional literal OpenRouter API key. This is convenient, but it can
              put the key in the Nix store and generated config files. Prefer
              `apiKeyFile` or inherited environment variables for real secrets.
            '';
          };

          apiKeyFile = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Optional file containing the OpenRouter API key.";
          };

          env = mkOption {
            type = types.attrsOf types.str;
            default = { };
            description = ''
              Additional environment for the OpenRouter Search MCP server. Use
              this for non-secret knobs or when deliberately passing a concrete
              environment value. If `OPENROUTER_API_KEY` is already exported in
              the shell running the AI client, leave this empty and the server
              can inherit it at runtime.
            '';
          };
        };
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      home.packages = packageSets.sharedAgentPackages;
      programs.git.ignores = lib.mkAfter gitIgnores;

      assertions = [
        {
          assertion = !cfg.mcp.servers.qmd.enable || qmdHasUsableDefinition;
          message = "programs.ai-tools.mcp.servers.qmd.enable requires qmd.url, mcp.serverOverrides.qmd.url, or a full local mcp.serverOverrides.qmd.command replacement.";
        }

      ];
    }

    (mkIf cfg.mcp.servers.serena.enable {
      # Only core language servers (gopls, nixd) are added automatically.
      # Rust support (rustup, zls) is available via packageSets.serenaRustPackages
      # but must be added explicitly: home.packages = packageSets.serenaRustPackages
      home.packages = packageSets.serenaSupportPackages;
    })

    (mkIf cfg.tools.claudeCode.enable {
      home.packages = packageSets.claudeCodeHelperPackages;

      programs.claude-code = mkMerge [
        {
          enable = true;
          package = mkDefault llmAgents.claude-code;
          mcpServers = mkDefault (mkToolMcpServers "claudecode" mcp.forClaudeCode);
          settings = mkDefault claudeCodeSettings;
          inherit (aiTools.claudeCode)
            agents
            commands
            skills
            ;
          memory.text = mkDefault instructions;
        }
        cfg.tools.claudeCode.program
      ];
    })

    (mkIf cfg.tools.codex.enable {
      home.packages = packageSets.codexHelperPackages;

      home.file = codexHomeFiles;

      programs.codex = mkMerge [
        {
          enable = true;
          package = mkDefault llmAgents.codex;
          settings = mkDefault codexSettings;
          "custom-instructions" = mkDefault instructions;
          skills = codexSkills;
        }
        cfg.tools.codex.program
      ];
    })

    (mkIf cfg.tools.opencode.enable {
      home.packages = packageSets.opencodeHelperPackages ++ extraOpencodePackages;
      home.file = extraOpencodeHomeFiles // defaultOpencodeCustomFiles;
    })

    (mkIf (cfg.tools.opencode.enable && defaultOpencodeEnabled) {

      programs.opencode = mkMerge [
        {
          enable = true;
          package = mkDefault defaultOpencodePackage;
          rules = mkDefault opencodeRules;
          settings = mkDefault opencodeSettings;
          inherit (aiTools.claudeCode)
            agents
            commands
            skills
            ;
        }
        cfg.tools.opencode.program
      ];
    })

    (mkIf
      (
        cfg.tools.opencode.enable
        && defaultOpencodeEnabled
        && defaultOpencodeProfile.dcp.enable
        && defaultOpencodeProfile.configDir == ".config/opencode"
      )
      {
        home.file.".config/opencode/dcp.jsonc".source =
          jsonFormat.generate "opencode-dcp" opencodeDcpSettings;
      }
    )

    (mkIf (cfg.tools.opencode.enable && opencodeRtkEnabled) {
      home.packages = [ opencodeSupport.rtkPackage ];
    })

    (mkIf
      (
        cfg.tools.opencode.enable
        && defaultOpencodeEnabled
        && defaultOpencodeProfile.rtk.enable
        && defaultOpencodeProfile.configDir == ".config/opencode"
      )
      {
        home.file = {
          ".config/opencode/plugins/rtk.ts".text = opencodeSupport.rtkPlugin;
          ".config/rtk/config.toml".text = opencodeSupport.mkRtkConfig {
            excludeCommands = defaultOpencodeProfile.rtk.excludeCommands;
            teeEnable = defaultOpencodeProfile.rtk.tee.enable;
            teeMode = defaultOpencodeProfile.rtk.tee.mode;
            telemetryEnable = defaultOpencodeProfile.rtk.telemetry.enable;
          };
        };
      }
    )
  ]);
}
