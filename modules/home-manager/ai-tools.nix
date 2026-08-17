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
    attrNames
    concatLists
    elem
    filterAttrs
    mapAttrs
    mapAttrsToList
    mkEnableOption
    mkDefault
    mkIf
    mkMerge
    mkOption
    optional
    optionals
    optionalAttrs
    optionalString
    recursiveUpdate
    types
    unique
    ;

  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  aiTools = import ../../ai-tools { inherit inputs lib pkgs; };
  mcp = import ../../lib/mcp.nix { inherit inputs lib pkgs; };
  opencodeSupport = import ../../lib/opencode.nix { inherit inputs lib pkgs; };
  ompSupport = import ../../lib/omp.nix { inherit inputs lib pkgs; };
  ompMcpSupport = import ../../lib/omp-mcp.nix { inherit inputs lib pkgs; };
  packageSets = import ../../lib/packages.nix { inherit inputs lib pkgs; };

  mkServerOption = description: default: {
    enable = mkEnableOption description // {
      inherit default;
    };
  };

  mkCollectionEnableOption =
    kind: groupName: members:
    mkEnableOption "${groupName} ${kind} (${lib.concatStringsSep ", " (attrNames members)})"
    // {
      default = true;
    };

  mkProfileServerOption = description: {
    enable = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Optional per-profile override for ${description}.";
    };
  };

  mkMcpInheritGlobalOption =
    default: description:
    mkOption {
      type = types.bool;
      inherit default description;
    };

  mkProfileMcpInheritGlobalOption =
    defaultDescription:
    mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Optional per-profile override for whether this MCP config inherits global
        `programs.ai-tools.mcp.*` servers, overrides, extra servers, and secrets.
        Defaults to ${defaultDescription}.
      '';
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

  permissionGatePatternType = types.submodule {
    options = {
      pattern = mkOption {
        type = types.str;
        description = "JavaScript regular expression pattern source.";
      };
      flags = mkOption {
        type = types.str;
        default = "";
        description = "JavaScript regular expression flags.";
      };
    };
  };

  mkMcpServerEnable =
    profileMcp: serverName:
    let
      profileServer = profileMcp.servers.${serverName};
    in
    if profileServer.enable != null then
      profileServer.enable
    else if profileMcp.inheritGlobal or true then
      cfg.mcp.servers.${serverName}.enable
    else
      false;

  mkEnabledMcpServerNames =
    profileMcp:
    optionals (mkMcpServerEnable profileMcp "sequential-thinking") [
      "sequential-thinking"
    ]
    ++ optionals (mkMcpServerEnable profileMcp "git") [ "git" ]
    ++ optionals (mkMcpServerEnable profileMcp "context7") [ "context7" ]
    ++ optionals (mkMcpServerEnable profileMcp "nixos") [ "nixos" ]
    ++ optionals (mkMcpServerEnable profileMcp "time") [ "time" ]
    ++ optionals (mkMcpServerEnable profileMcp "fetch") [ "fetch" ]
    ++ optionals (mkMcpServerEnable profileMcp "memory") [ "memory" ]
    ++ optionals (mkMcpServerEnable profileMcp "serena") [ "serena" ]
    ++ optionals (mkMcpServerEnable profileMcp "playwright") [
      "playwright"
    ]
    ++ optionals (mkMcpServerEnable profileMcp "filesystem") [
      "filesystem"
    ]
    ++ optionals (mkMcpServerEnable profileMcp "notebooklm") [
      "notebooklm"
    ]
    ++ optionals (mkMcpServerEnable profileMcp "basic-memory") [
      "basic-memory"
    ]
    ++ optionals (mkMcpServerEnable profileMcp "terraform") [
      "terraform"
    ]
    ++ optionals (mkMcpServerEnable profileMcp "qmd") [ "qmd" ]
    ++ optionals (mkMcpServerEnable profileMcp "deepwiki") [ "deepwiki" ]
    ++ optionals (mkMcpServerEnable profileMcp "exa") [ "exa" ]
    ++ optionals (mkMcpServerEnable profileMcp "openrouter-search") [
      "openrouter-search"
    ];

  cavemanSkillNames = [
    "caveman"
    "caveman-commit"
    "caveman-review"
    "caveman-help"
    "caveman-compress"
    "caveman-stats"
    "cavecrew"
  ];

  commandGroups = aiTools.commandGroups;
  agentGroups = aiTools.agentGroups;

  allCommandNames = attrNames aiTools.claudeCode.commands;
  allAgentNames = attrNames aiTools.claudeCode.agents;

  enabledCommandNames = lib.subtractLists cfg.disabledCommands (
    unique (
      concatLists (
        mapAttrsToList (
          groupName: commands: optionals cfg.commands.${groupName}.enable (attrNames commands)
        ) commandGroups
      )
    )
  );

  enabledAgentNames = lib.subtractLists cfg.disabledAgents (
    unique (
      concatLists (
        mapAttrsToList (
          groupName: agents: optionals cfg.agents.${groupName}.enable (attrNames agents)
        ) agentGroups
      )
    )
  );

  unknownDisabledCommands = lib.subtractLists allCommandNames cfg.disabledCommands;
  unknownDisabledAgents = lib.subtractLists allAgentNames cfg.disabledAgents;

  filterCommands = commands: filterAttrs (name: _: elem name enabledCommandNames) commands;
  filterAgents = agents: filterAttrs (name: _: elem name enabledAgentNames) agents;
  mattpocockSkillNames = [
    "diagnose"
    "grill-with-docs"
    "triage"
    "improve-codebase-architecture"
    "setup-matt-pocock-skills"
    "tdd"
    "to-tickets"
    "to-spec"
    "prototype"
    "grill-me"
    "handoff"
    "writing-for-agents"
  ];

  superpowersSkillNames = [
    "brainstorming"
    "dispatching-parallel-agents"
    "executing-plans"
    "finishing-a-development-branch"
    "receiving-code-review"
    "requesting-code-review"
    "subagent-driven-development"
    "systematic-debugging"
    "test-driven-development"
    "using-git-worktrees"
    "using-superpowers"
    "verification-before-completion"
    "writing-plans"
    "writing-skills"
  ];

  enabledSkillNames = unique (
    (if cfg.skills.notebooklm.enable then [ "notebooklm" ] else [ ])
    ++ (if cfg.skills.rtk.enable then [ "rtk" ] else [ ])
    ++ (if cfg.skills.agentBrowser.enable then [ "agent-browser" ] else [ ])
    ++ (if cfg.skills.basicMemory.enable then [ "basic-memory" ] else [ ])
    ++ (if cfg.skills.dcp.enable then [ "dcp" ] else [ ])
    ++ (if cfg.skills.karpathyGuidelines.enable then [ "karpathy-guidelines" ] else [ ])
    ++ (if cfg.skills.terraform.enable then [ "terraform" ] else [ ])
    ++ (if cfg.skills.gog.enable then [ "gog" ] else [ ])
    ++ optionals cfg.skills.caveman.enable cavemanSkillNames
    ++ optionals cfg.skills.mattpocock.enable mattpocockSkillNames
    ++ optionals cfg.skills.superpowers.enable superpowersSkillNames
  );

  filterSkills = skills: filterAttrs (name: _: elem name enabledSkillNames) skills;

  filterSkillFiles = skillFiles: filterAttrs (name: _: elem name enabledSkillNames) skillFiles;

  mkSkillExtraHomeFiles =
    baseDir: skillFiles:
    lib.concatMapAttrs (
      skillName: files:
      lib.mapAttrs' (relPath: file: lib.nameValuePair "${baseDir}/${skillName}/${relPath}" file) files
    ) (filterSkillFiles skillFiles);

  mkSkillHomeFile =
    skill:
    if
      builtins.typeOf skill == "path" || (builtins.typeOf skill == "string" && builtins.hasContext skill)
    then
      { source = "${skill}/SKILL.md"; }
    else
      { text = skill; };

  removeNullMcpValues =
    attrs:
    lib.filterAttrs (_: value: value != null && value != { }) (
      lib.mapAttrs (_: value: if builtins.isAttrs value then removeNullMcpValues value else value) attrs
    );

  defaultProfileMcp = {
    inheritGlobal = true;
    memoryDir = null;
    serverOverrides = { };
    extraServers = { };
    servers = lib.recursiveUpdate (lib.mapAttrs (_: _: { enable = null; }) cfg.mcp.servers) {
      qmd.url = null;
      openrouter-search = {
        apiKey = null;
        apiKeyFile = null;
        env = { };
      };
    };
  };

  globalMcpForTools = defaultProfileMcp;

  mkProfileMcpConfig =
    profileMcp:
    let
      profileOpenrouter = profileMcp.servers.openrouter-search;
      hasProfileOpenrouterSecret =
        profileOpenrouter.apiKey != null || profileOpenrouter.apiKeyFile != null;
    in
    {
      enabledServerNames = mkEnabledMcpServerNames profileMcp;
      filesystemAllowedPaths = cfg.mcp.filesystem.allowedPaths;
      memoryBaseDir = cfg.mcp.memoryBaseDir;
      memoryDir = profileMcp.memoryDir;
      qmdUrl =
        if profileMcp.servers.qmd.url != null then
          profileMcp.servers.qmd.url
        else if profileMcp.inheritGlobal or true then
          cfg.mcp.servers.qmd.url
        else
          null;
      openrouterSearchApiKey =
        if hasProfileOpenrouterSecret then
          profileOpenrouter.apiKey
        else if profileMcp.inheritGlobal or true then
          cfg.mcp.servers.openrouter-search.apiKey
        else
          null;
      openrouterSearchApiKeyFile =
        if hasProfileOpenrouterSecret then
          profileOpenrouter.apiKeyFile
        else if profileMcp.inheritGlobal or true then
          cfg.mcp.servers.openrouter-search.apiKeyFile
        else
          null;
      openrouterSearchEnv =
        optionalAttrs (profileMcp.inheritGlobal or true) cfg.mcp.servers.openrouter-search.env
        // profileOpenrouter.env;
      serverOverrides =
        optionalAttrs (profileMcp.inheritGlobal or true) cfg.mcp.serverOverrides
        // profileMcp.serverOverrides;
      extraServers =
        optionalAttrs (profileMcp.inheritGlobal or true) cfg.mcp.extraServers // profileMcp.extraServers;
    };

  mkToolMcpServers =
    toolName: inheritGlobal: builder:
    builder (
      mkProfileMcpConfig (
        globalMcpForTools
        // {
          inherit inheritGlobal;
          memoryDir = "${cfg.profileName}-${toolName}";
        }
      )
    );

  mkOpencodeMcpServers = profileMcp: mcp.forOpenCode (mkProfileMcpConfig profileMcp);

  jsonFormat = pkgs.formats.json { };
  yamlFormat = pkgs.formats.yaml { };

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

    # Memory persistence is opt-in (clean context by default). Enable via
    # `tools.codex.settings.memories = { generate_memories = true; use_memories = true; };`.
    memories = {
      generate_memories = false;
      use_memories = false;
    };

    analytics.enabled = false;

    mcp_servers = mkToolMcpServers "codex" cfg.tools.codex.mcp.inheritGlobal mcp.forCodex;
  };

  codexSettings = lib.recursiveUpdate (lib.recursiveUpdate codexDefaultSettings cfg.tools.codex.settings) cfg.tools.codex.extraSettings;

  codexSkills = filterSkills aiTools.codex.skills;

  codexHomeFiles =
    lib.mapAttrs' (name: prompt: lib.nameValuePair ".codex/prompts/${name}.md" { text = prompt; }) (
      filterCommands aiTools.codex.prompts
    )
    // lib.mapAttrs' (
      skillName: skill: lib.nameValuePair ".agents/skills/${skillName}/SKILL.md" (mkSkillHomeFile skill)
    ) (filterSkills aiTools.codex.skills)
    // mkSkillExtraHomeFiles ".agents/skills" aiTools.codex.skillFiles
    // lib.mapAttrs' (
      name: skill: lib.nameValuePair ".agents/skills/${name}/SKILL.md" { text = skill.skillMd; }
    ) (filterAgents aiTools.codex.agentSkills)
    // lib.mapAttrs' (
      name: skill:
      lib.nameValuePair ".agents/skills/${name}/agents/openai.yaml" { text = skill.openaiYaml; }
    ) (filterAgents aiTools.codex.agentSkills);

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
      mcp = mkOpencodeMcpServers profile.mcp;
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

  mkOpencodeExtraFile =
    profileName: path: file:
    let
      fileName = lib.replaceStrings [ "/" ] [ "-" ] path;
    in
    if file ? value then
      builtins.removeAttrs file [
        "source"
        "text"
        "value"
      ]
      // {
        source = jsonFormat.generate "opencode-${profileName}-${fileName}" file.value;
      }
    else
      file;

  mkOpencodeProfileFiles =
    name: profile:
    let
      sharedFiles =
        lib.optionalAttrs (cfg.instructions != "") {
          "${profile.configDir}/AGENTS.md".text = cfg.instructions;
        }
        // lib.mapAttrs' (
          agentName: agent: lib.nameValuePair "${profile.configDir}/agents/${agentName}.md" { text = agent; }
        ) (filterAgents aiTools.opencode.agents)
        // lib.mapAttrs' (
          commandName: command:
          lib.nameValuePair "${profile.configDir}/commands/${commandName}.md" { text = command; }
        ) (filterCommands aiTools.opencode.commands)
        // lib.mapAttrs' (
          skillName: skill:
          lib.nameValuePair "${profile.configDir}/skills/${skillName}/SKILL.md" (mkSkillHomeFile skill)
        ) (filterSkills aiTools.claudeCode.skills)
        // mkSkillExtraHomeFiles "${profile.configDir}/skills" aiTools.claudeCode.skillFiles;
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
        path: file: lib.nameValuePair "${profile.configDir}/${path}" (mkOpencodeExtraFile name path file)
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
    mcp = defaultProfileMcp // {
      enable = true;
      inheritGlobal = cfg.tools.opencode.mcp.inheritGlobal;
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
      profileMcpWithoutInheritGlobal = lib.removeAttrs (removeNullMcpValues (baseProfile.mcp or { })) [
        "inheritGlobal"
      ];
      profileMcpInheritGlobal =
        if (baseProfile.mcp or { }).inheritGlobal != null then
          baseProfile.mcp.inheritGlobal
        else
          cfg.tools.opencode.mcp.inheritGlobal;
      baseProfileMcp = lib.recursiveUpdate defaultProfileMcp profileMcpWithoutInheritGlobal // {
        inheritGlobal = profileMcpInheritGlobal;
      };
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
        baseProfileMcp
        // optionalAttrs (baseProfileMcp.memoryDir == null) {
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

  opencodeDcpEnabled = lib.any (profile: profile.dcp.enable) (lib.attrValues enabledOpencodeProfiles);

  validEnvName = name: builtins.match "[A-Za-z_][A-Za-z0-9_]*" name != null;

  invalidOmpEnvNames = lib.filter (name: !(validEnvName name)) (
    attrNames cfg.tools.omp.env
    ++ attrNames cfg.tools.omp.envFiles
    ++ concatLists (map (profile: attrNames profile.env) (lib.attrValues cfg.tools.omp.profiles))
    ++ concatLists (map (profile: attrNames profile.envFiles) (lib.attrValues cfg.tools.omp.profiles))
  );

  ompConfigOnlyKeys = [
    "modelRoles"
    "modelProviderOrder"
    "enabledModels"
    "disabledProviders"
  ];

  ompModelsOnlySettings = attrs: lib.removeAttrs attrs ompConfigOnlyKeys;

  mergeOmpAttrs = lib.foldl' recursiveUpdate { };

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
    ++ optional cfg.tools.opencode.enable ".opencode/"
    ++ optional cfg.tools.omp.enable ".omp/";

  # ── omp config generation ──

  mkOmpMcpConfig =
    profileMcp:
    let
      profileOpenrouter = profileMcp.servers.openrouter-search;
      hasProfileOpenrouterSecret =
        profileOpenrouter.apiKey != null || profileOpenrouter.apiKeyFile != null;
    in
    {
      enabledServerNames = mkEnabledMcpServerNames profileMcp;
      filesystemAllowedPaths = cfg.mcp.filesystem.allowedPaths;
      memoryBaseDir = cfg.mcp.memoryBaseDir;
      memoryDir = profileMcp.memoryDir;
      qmdUrl =
        if profileMcp.servers.qmd.url != null then
          profileMcp.servers.qmd.url
        else if profileMcp.inheritGlobal or true then
          cfg.mcp.servers.qmd.url
        else
          null;
      openrouterSearchApiKey =
        if hasProfileOpenrouterSecret then
          profileOpenrouter.apiKey
        else if profileMcp.inheritGlobal or true then
          cfg.mcp.servers.openrouter-search.apiKey
        else
          null;
      openrouterSearchApiKeyFile =
        if hasProfileOpenrouterSecret then
          profileOpenrouter.apiKeyFile
        else if profileMcp.inheritGlobal or true then
          cfg.mcp.servers.openrouter-search.apiKeyFile
        else
          null;
      openrouterSearchEnv =
        optionalAttrs (profileMcp.inheritGlobal or true) cfg.mcp.servers.openrouter-search.env
        // profileOpenrouter.env;
      serverOverrides =
        optionalAttrs (profileMcp.inheritGlobal or true) cfg.mcp.serverOverrides
        // profileMcp.serverOverrides;
      extraServers =
        optionalAttrs (profileMcp.inheritGlobal or true) cfg.mcp.extraServers // profileMcp.extraServers;
    };

  mkOmpGeneratedConfig =
    profile:
    let
      theme = {
        dark = if profile.theme.dark != null then profile.theme.dark else cfg.tools.omp.theme.dark;
        light = if profile.theme.light != null then profile.theme.light else cfg.tools.omp.theme.light;
      };
    in
    ompSupport.mkOmpConfig {
      inherit theme;
      symbolPreset = cfg.tools.omp.symbolPreset;
      defaultThinkingLevel = cfg.tools.omp.defaultThinkingLevel;
      hideThinkingBlock = cfg.tools.omp.hideThinkingBlock;
      terminal.showImages = cfg.tools.omp.terminal.showImages;
      steeringMode = cfg.tools.omp.steeringMode;
      followUpMode = cfg.tools.omp.followUpMode;
      interruptMode = cfg.tools.omp.interruptMode;
      compaction = {
        enabled = cfg.tools.omp.compaction.enabled;
        reserveTokens = cfg.tools.omp.compaction.reserveTokens;
        keepRecentTokens = cfg.tools.omp.compaction.keepRecentTokens;
        autoContinue = cfg.tools.omp.compaction.autoContinue;
        strategy = cfg.tools.omp.compaction.strategy;
      };
      skills.enabled = cfg.tools.omp.skills.enabled;
      memories.enabled = cfg.tools.omp.memories.enabled;
      temperature = cfg.tools.omp.temperature;
      topP = cfg.tools.omp.topP;
      edit.mode = cfg.tools.omp.edit.mode;
      lsp = {
        enabled = cfg.tools.omp.lsp.enabled;
        formatOnWrite = cfg.tools.omp.lsp.formatOnWrite;
      };
      bashInterceptor.enabled = cfg.tools.omp.bashInterceptor.enabled;
    };

  mkOmpGeneratedModels = { };

  mkOmpConfigYaml =
    profile:
    mergeOmpAttrs [
      (mkOmpGeneratedConfig profile)
      cfg.tools.omp.settings
      cfg.tools.omp.extraSettings
      (profile.settings or { })
    ];

  mkOmpModelsYaml =
    profile:
    mergeOmpAttrs [
      mkOmpGeneratedModels
      (ompModelsOnlySettings cfg.tools.omp.modelSettings)
      (ompModelsOnlySettings cfg.tools.omp.extraModelSettings)
      (ompModelsOnlySettings (profile.modelSettings or { }))
    ];

  mkOmpMcpJson =
    profile:
    let
      mcpProfile = profile.mcp;
    in
    let
      mcpEnable = if mcpProfile.enable != null then mcpProfile.enable else cfg.tools.omp.mcp.enable;
    in
    if mcpEnable then
      ompMcpSupport.forOmp (
        let
          p = mkOmpMcpConfig mcpProfile;
        in
        {
          inherit (p)
            enabledServerNames
            filesystemAllowedPaths
            memoryBaseDir
            qmdUrl
            openrouterSearchApiKey
            openrouterSearchApiKeyFile
            openrouterSearchEnv
            serverOverrides
            extraServers
            ;
          memoryDir = if mcpProfile.memoryDir != null then mcpProfile.memoryDir else "${cfg.profileName}-omp";
        }
      )
    else
      null;

  legacyOmpProfile = {
    enable = cfg.tools.omp.enable;
    commandName = "omp";
    configDir = ".omp";
    package = cfg.tools.omp.package;
    inherit (cfg.tools.omp)
      env
      envFiles
      extraRuntimePackages
      ;
    theme = {
      dark = cfg.tools.omp.theme.dark;
      light = cfg.tools.omp.theme.light;
    };
    hooks = {
      permissionGate = {
        enable = cfg.tools.omp.hooks.permissionGate.enable;
        blockedPatterns = cfg.tools.omp.hooks.permissionGate.blockedPatterns;
        blockedCommands = cfg.tools.omp.hooks.permissionGate.blockedCommands;
        extraBlockedPatterns = cfg.tools.omp.hooks.permissionGate.extraBlockedPatterns;
        extraBlockedCommands = cfg.tools.omp.hooks.permissionGate.extraBlockedCommands;
        mode = cfg.tools.omp.hooks.permissionGate.mode;
      };
      protectedPaths = {
        enable = cfg.tools.omp.hooks.protectedPaths.enable;
        globs = cfg.tools.omp.hooks.protectedPaths.globs;
        extraGlobs = cfg.tools.omp.hooks.protectedPaths.extraGlobs;
        protectReads = cfg.tools.omp.hooks.protectedPaths.protectReads;
        mode = cfg.tools.omp.hooks.protectedPaths.mode;
      };
      pathAccess = {
        mode = cfg.tools.omp.hooks.pathAccess.mode;
        allowPaths = cfg.tools.omp.hooks.pathAccess.allowPaths;
        denyPaths = cfg.tools.omp.hooks.pathAccess.denyPaths;
      };
      custom = cfg.tools.omp.hooks.custom;
    };
    mcp = {
      enable = cfg.tools.omp.mcp.enable;
      inheritGlobal = cfg.tools.omp.mcp.inheritGlobal;
      memoryDir =
        if cfg.tools.omp.mcp.memoryDir != null then
          cfg.tools.omp.mcp.memoryDir
        else
          "${cfg.profileName}-omp";
      serverOverrides = cfg.tools.omp.mcp.serverOverrides;
      extraServers = cfg.tools.omp.mcp.extraServers;
      servers = defaultProfileMcp.servers // cfg.tools.omp.mcp.servers;
    };
  };

  ompProfiles = lib.mapAttrs (
    _name: profile:
    let
      baseProfile = recursiveUpdate legacyOmpProfile profile;
      hooksProfile = removeNullMcpValues (baseProfile.hooks or { });
      hooksResolved = recursiveUpdate legacyOmpProfile.hooks hooksProfile;
      profileMcpWithoutInheritGlobal = lib.removeAttrs (removeNullMcpValues (baseProfile.mcp or { })) [
        "inheritGlobal"
      ];
      profileMcpInheritGlobal =
        if (baseProfile.mcp or { }).inheritGlobal != null then
          baseProfile.mcp.inheritGlobal
        else
          cfg.tools.omp.mcp.inheritGlobal;
      profileMcp =
        recursiveUpdate {
          enable = legacyOmpProfile.mcp.enable;
          inheritGlobal = profileMcpInheritGlobal;
          serverOverrides = { };
          extraServers = { };
          servers = legacyOmpProfile.mcp.servers;
        } profileMcpWithoutInheritGlobal
        // {
          inheritGlobal = profileMcpInheritGlobal;
        };
    in
    baseProfile
    // {
      commandName =
        if baseProfile.commandName != null then baseProfile.commandName else legacyOmpProfile.commandName;
      package = if baseProfile.package != null then baseProfile.package else legacyOmpProfile.package;
      configDir =
        if baseProfile.configDir != null then baseProfile.configDir else legacyOmpProfile.configDir;
      hooks = hooksResolved;
      mcp = profileMcp;
    }
  ) ({ default = { }; } // cfg.tools.omp.profiles);

  enabledOmpProfiles = lib.filterAttrs (_name: profile: profile.enable) ompProfiles;

  # Each profile gets a .omp/<profile> config dir under home
  mkOmpProfileFiles =
    name: profile:
    let
      dir = profile.configDir;
      configYaml = mkOmpConfigYaml profile;
      modelsYaml = mkOmpModelsYaml profile;
      configContent = yamlFormat.generate "omp-${name}-config" configYaml;
      modelsContent = yamlFormat.generate "omp-${name}-models" modelsYaml;
      mcpJson = mkOmpMcpJson profile;

      hookFiles =
        lib.optionalAttrs (profile.hooks.permissionGate.enable or false) {
          "agent/extensions/permission-gate.ts" = {
            text = ompSupport.mkPermissionGateHook profile.hooks.permissionGate;
          };
        }
        // lib.optionalAttrs (profile.hooks.protectedPaths.enable or false) {
          "agent/extensions/protected-paths.ts" = {
            text = ompSupport.mkProtectedPathsHook (
              profile.hooks.protectedPaths
              // {
                allowPaths = profile.hooks.pathAccess.allowPaths or ompSupport.defaultPathAccessAllowPaths;
                denyPaths = profile.hooks.pathAccess.denyPaths or ompSupport.defaultPathAccessDenyPaths;
                pathAccessMode = profile.hooks.pathAccess.mode or "ask";
              }
            );
          };
        }
        // lib.mapAttrs' (
          hookName: hookContent:
          lib.nameValuePair "agent/extensions/${lib.removeSuffix ".ts" hookName}.ts" {
            text = hookContent;
          }
        ) profile.hooks.custom;
    in
    {
      "${dir}/agent/config.yml".source = configContent;
      "${dir}/agent/models.yml".source = modelsContent;
    }
    // lib.optionalAttrs (mcpJson != null) {
      "${dir}/agent/mcp.json".source = mcpJson;
    }
    // lib.mapAttrs' (relPath: file: lib.nameValuePair "${dir}/${relPath}" file) hookFiles
    // lib.mapAttrs' (
      agentName: agent: lib.nameValuePair "${dir}/agent/agents/${agentName}.md" { text = agent; }
    ) (filterAgents aiTools.omp.agents)
    // lib.mapAttrs' (
      commandName: command:
      lib.nameValuePair "${dir}/agent/commands/${commandName}.md" { text = command; }
    ) (filterCommands aiTools.omp.commands)
    // lib.mapAttrs' (
      skillName: skill:
      lib.nameValuePair "${dir}/agent/skills/${skillName}/SKILL.md" (mkSkillHomeFile skill)
    ) (filterSkills aiTools.omp.skills)
    // mkSkillExtraHomeFiles "${dir}/agent/skills" aiTools.omp.skillFiles;

  # Wrappers for each profile with a commandName
  mkOmpProfileWrapper = name: profile: ompSupport.mkOmpWrapper profile false;

  ompWrapperPackages = lib.mapAttrsToList (_name: profile: mkOmpProfileWrapper _name profile) (
    lib.filterAttrs (_name: profile: profile.commandName != null) enabledOmpProfiles
  );

  allKnownSkillNames = unique (
    cavemanSkillNames
    ++ mattpocockSkillNames
    ++ superpowersSkillNames
    ++ [
      "notebooklm"
      "rtk"
      "agent-browser"
      "basic-memory"
      "dcp"
      "karpathy-guidelines"
      "terraform"
      "gog"
    ]
  );

  orphanableSkillNames = lib.subtractLists enabledSkillNames allKnownSkillNames;

  managedSkillRoots =
    optionals cfg.tools.codex.enable [ ".agents/skills" ]
    ++ optionals cfg.tools.opencode.enable (
      map (profile: "${profile.configDir}/skills") (lib.attrValues enabledOpencodeProfiles)
    )
    ++ optionals cfg.tools.omp.enable (
      map (profile: "${profile.configDir}/agent/skills") (lib.attrValues enabledOmpProfiles)
    );
in
{
  options.programs.ai-tools = {
    enable = mkEnableOption "shared AI CLI setup";

    instructions = mkOption {
      type = types.lines;
      default = "";
      example = "You operate in a NixOS environment. Prefer declarative config.";
      description = ''
        Shared system prompt injected as context into every enabled tool
        (Claude Code & Codex `context`, OpenCode `AGENTS.md` and `context`).
        Empty by default: no context file is written, so each tool keeps its
        own defaults. Set it (e.g. `builtins.readFile ./system-prompt.md`) to
        opt into shared instructions. See `examples/home-manager`.
      '';
    };

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

        mcp.inheritGlobal = mkMcpInheritGlobalOption true ''
          Whether Claude Code MCP config starts from global
          `programs.ai-tools.mcp.*` servers and raw server definitions.
        '';

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

        mcp.inheritGlobal = mkMcpInheritGlobalOption true ''
          Whether Codex MCP config starts from global
          `programs.ai-tools.mcp.*` servers and raw server definitions.
        '';

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

        mcp.inheritGlobal = mkMcpInheritGlobalOption true ''
          Whether OpenCode profiles inherit global `programs.ai-tools.mcp.*`
          servers, overrides, extra servers, and secrets by default. Individual
          profiles can override this with `tools.opencode.profiles.<name>.mcp.inheritGlobal`.
        '';

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
                    description = ''
                      Extra Home Manager `home.file` entries written under this
                      profile's config directory. Entries support standard
                      `home.file` forms such as `text` and `source`; entries
                      with `value` are rendered as JSON.
                    '';
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

                    inheritGlobal = mkProfileMcpInheritGlobalOption "`tools.opencode.mcp.inheritGlobal`";

                    memoryDir = mkOption {
                      type = types.nullOr types.str;
                      default = null;
                      description = "MCP memory directory name for this profile.";
                    };

                    serverOverrides = mkOption {
                      type = types.attrsOf types.anything;
                      default = { };
                      description = "Per-profile MCP server overrides merged over global overrides.";
                    };

                    extraServers = mkOption {
                      type = types.attrsOf types.anything;
                      default = { };
                      description = "Per-profile MCP extra servers merged with global extra servers.";
                    };

                    servers = {
                      sequential-thinking = mkProfileServerOption "the sequential-thinking MCP server";
                      git = mkProfileServerOption "the git MCP server";
                      context7 = mkProfileServerOption "the Context7 MCP server";
                      nixos = mkProfileServerOption "the nixos MCP server";
                      time = mkProfileServerOption "the time MCP server";
                      fetch = mkProfileServerOption "the fetch MCP server";
                      memory = mkProfileServerOption "the memory MCP server";
                      serena = mkProfileServerOption "the serena MCP server";
                      playwright = mkProfileServerOption "the playwright MCP server";
                      filesystem = mkProfileServerOption "the filesystem MCP server";
                      notebooklm = mkProfileServerOption "the NotebookLM MCP server";
                      basic-memory = mkProfileServerOption "the Basic Memory MCP server";
                      terraform = mkProfileServerOption "the Terraform MCP server";
                      qmd = mkProfileServerOption "the QMD MCP server" // {
                        url = mkOption {
                          type = types.nullOr types.str;
                          default = null;
                          description = "Optional per-profile QMD MCP URL override.";
                        };
                      };
                      deepwiki = mkProfileServerOption "the DeepWiki MCP server";
                      exa = mkProfileServerOption "the Exa MCP server";
                      openrouter-search = mkProfileServerOption "the OpenRouter Search MCP server" // {
                        apiKey = mkOption {
                          type = types.nullOr types.str;
                          default = null;
                          description = "Optional per-profile literal OpenRouter API key override.";
                        };

                        apiKeyFile = mkOption {
                          type = types.nullOr types.str;
                          default = null;
                          description = "Optional per-profile file containing the OpenRouter API key.";
                        };

                        env = mkOption {
                          type = types.attrsOf types.str;
                          default = { };
                          description = "Additional per-profile environment for the OpenRouter Search MCP server.";
                        };
                      };
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

      omp = {
        enable = mkEnableOption "omp (oh-my-pi) coding agent" // {
          default = false;
        };

        package = mkOption {
          type = types.package;
          default = llmAgents.omp;
          defaultText = "pkgs.llm-agents.omp";
          description = "omp package to use.";
        };

        settings = mkOption {
          type = types.attrsOf types.anything;
          default = { };
          description = "Additional omp config.yml settings merged into module defaults.";
        };

        extraSettings = mkOption {
          type = types.attrsOf types.anything;
          default = { };
          description = "Final config.yml override merged after `settings`.";
        };

        modelSettings = mkOption {
          type = types.attrsOf types.anything;
          default = { };
          description = "Additional models.yml settings merged into module defaults.";
        };

        extraModelSettings = mkOption {
          type = types.attrsOf types.anything;
          default = { };
          description = "Final models.yml override merged after `modelSettings`.";
        };

        theme = {
          dark = mkOption {
            type = types.str;
            default = "titanium";
            description = "omp dark theme name.";
          };
          light = mkOption {
            type = types.str;
            default = "light";
            description = "omp light theme name.";
          };
        };

        symbolPreset = mkOption {
          type = types.enum [
            "unicode"
            "nerd"
            "ascii"
          ];
          default = "unicode";
          description = "omp symbol/icon preset.";
        };

        defaultThinkingLevel = mkOption {
          type = types.enum [
            "low"
            "medium"
            "high"
          ];
          default = "high";
          description = "Default thinking level for omp.";
        };

        hideThinkingBlock = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to collapse thinking blocks by default.";
        };

        terminal.showImages = mkOption {
          type = types.bool;
          default = true;
          description = "Show images inline in the terminal.";
        };

        steeringMode = mkOption {
          type = types.enum [
            "one-at-a-time"
            "all-at-once"
          ];
          default = "one-at-a-time";
          description = "How omp handles concurrent tool calls.";
        };

        followUpMode = mkOption {
          type = types.enum [
            "one-at-a-time"
            "all-at-once"
          ];
          default = "one-at-a-time";
          description = "How omp handles follow-up suggestions.";
        };

        interruptMode = mkOption {
          type = types.enum [
            "immediate"
            "delayed"
          ];
          default = "immediate";
          description = "How omp handles user interrupts.";
        };

        compaction = {
          enabled = mkOption {
            type = types.bool;
            default = true;
            description = "Enable automatic message compaction.";
          };
          reserveTokens = mkOption {
            type = types.int;
            default = 16384;
            description = "Tokens to reserve during compaction.";
          };
          keepRecentTokens = mkOption {
            type = types.int;
            default = 20000;
            description = "Tokens to keep from recent conversation.";
          };
          autoContinue = mkOption {
            type = types.bool;
            default = true;
            description = "Auto-continue after compaction.";
          };
          strategy = mkOption {
            type = types.enum [
              "context-full"
              "handoff"
              "off"
            ];
            default = "context-full";
            description = "Compaction strategy.";
          };
        };

        skills.enabled = mkOption {
          type = types.bool;
          default = true;
          description = "Enable omp skill loading.";
        };

        memories.enabled = mkOption {
          type = types.bool;
          default = false;
          description = "Enable omp memory persistence.";
        };

        temperature = mkOption {
          type = types.float;
          default = -1.0;
          description = "Model temperature (-1 = provider default).";
        };

        topP = mkOption {
          type = types.float;
          default = -1.0;
          description = "Top-p sampling (-1 = provider default).";
        };

        edit.mode = mkOption {
          type = types.enum [
            "hashline"
            "search-replace"
            "diff"
          ];
          default = "hashline";
          description = "File editing mode.";
        };

        lsp = {
          enabled = mkOption {
            type = types.bool;
            default = true;
            description = "Enable LSP integration.";
          };
          formatOnWrite = mkOption {
            type = types.bool;
            default = false;
            description = "Run formatter on file writes via LSP.";
          };
        };

        bashInterceptor.enabled = mkOption {
          type = types.bool;
          default = false;
          description = "Enable the bash command interceptor.";
        };

        hooks = {
          permissionGate = {
            enable = mkEnableOption "permission gate hook (blocks rm -rf, sudo, chmod 777, etc.)" // {
              default = true;
            };
            blockedPatterns = mkOption {
              type = types.listOf permissionGatePatternType;
              default = ompSupport.defaultPermissionGateBlockedPatterns;
              description = "Regular expressions blocked by the omp permission gate hook.";
            };
            extraBlockedPatterns = mkOption {
              type = types.listOf permissionGatePatternType;
              default = [ ];
              description = "Additional regular expressions appended to the omp permission gate defaults.";
            };
            blockedCommands = mkOption {
              type = types.listOf types.str;
              default = ompSupport.defaultPermissionGateBlockedCommands;
              description = "Command names blocked by the omp permission gate hook.";
            };
            extraBlockedCommands = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Additional command names appended to the omp permission gate defaults.";
            };
            mode = mkOption {
              type = types.enum [
                "block"
                "ask"
              ];
              default = "ask";
              description = ''
                Response mode for the permission gate hook:
                - "block": Hard-block matching commands.
                - "ask": Prompt for user confirmation (falls back to block when no UI is available).
              '';
            };
          };
          protectedPaths = {
            enable =
              mkEnableOption "protected paths hook (blocks writes to .env, .git/, node_modules/, etc.)"
              // {
                default = true;
              };
            globs = mkOption {
              type = types.listOf types.str;
              default = ompSupport.defaultProtectedPathGlobs;
              description = "Path globs blocked by the omp protected paths hook.";
            };
            extraGlobs = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Additional path globs appended to the omp protected paths defaults.";
            };

            protectReads = mkOption {
              type = types.bool;
              default = true;
              description = ''
                When true, the protected paths hook also blocks read operations
                (read, find, search, grep) on protected paths, not just writes.
              '';
            };

            mode = mkOption {
              type = types.enum [
                "block"
                "ask"
              ];
              default = "ask";
              description = ''
                Response mode for protected path matches:
                - "block": Hard-block access to protected paths.
                - "ask": Prompt for user confirmation with once/session/always choices.
              '';
            };
          };

          pathAccess = {
            mode = mkOption {
              type = types.enum [
                "block"
                "ask"
                "allow"
              ];
              default = "ask";
              description = ''
                Response mode for the path access hook. Path access checks are
                part of the protected-paths hook, so they require
                `protectedPaths.enable = true`; set this to "allow" to disable
                them while keeping protected-path globs.
                - "block": Hard-block out-of-workspace access.
                - "ask": Prompt for user confirmation with once/session/always choices.
                - "allow": Allow all out-of-workspace access.
              '';
            };
            allowPaths = mkOption {
              type = types.listOf types.str;
              default = ompSupport.defaultPathAccessAllowPaths;
              description = "Paths always allowed for out-of-workspace access.";
            };
            denyPaths = mkOption {
              type = types.listOf types.str;
              default = ompSupport.defaultPathAccessDenyPaths;
              description = "Paths always denied for access.";
            };
          };
          custom = mkOption {
            type = types.attrsOf types.lines;
            default = { };
            example = {
              "audit-log" = ''
                export default function (pi) {
                  pi.on("tool_call", function (call) {
                    console.error("[audit]", call.toolName)
                  })
                }
              '';
            };
            description = ''
              Additional OMP ExtensionAPI hooks written to `agent/extensions`.
              Attribute names are hook filenames without the `.ts` suffix.
            '';
          };
        };

        mcp = {
          enable = mkEnableOption "MCP server support for omp" // {
            default = true;
          };

          inheritGlobal = mkMcpInheritGlobalOption true ''
            Whether omp MCP config starts from global `programs.ai-tools.mcp.*`
            servers, overrides, extra servers, and secrets.
          '';

          memoryDir = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "MCP memory directory name for omp.";
          };

          serverOverrides = mkOption {
            type = types.attrsOf types.anything;
            default = { };
            description = "MCP server definition overrides for omp.";
          };

          extraServers = mkOption {
            type = types.attrsOf types.anything;
            default = { };
            description = "Additional MCP server definitions for omp.";
          };

          servers = {
            sequential-thinking = mkProfileServerOption "the sequential-thinking MCP server for omp";
            git = mkProfileServerOption "the git MCP server for omp";
            context7 = mkProfileServerOption "the Context7 MCP server for omp";
            nixos = mkProfileServerOption "the nixos MCP server for omp";
            time = mkProfileServerOption "the time MCP server for omp";
            fetch = mkProfileServerOption "the fetch MCP server for omp";
            memory = mkProfileServerOption "the memory MCP server for omp";
            serena = mkProfileServerOption "the serena MCP server for omp";
            playwright = mkProfileServerOption "the playwright MCP server for omp";
            filesystem = mkProfileServerOption "the filesystem MCP server for omp";
            notebooklm = mkProfileServerOption "the NotebookLM MCP server for omp";
            basic-memory = mkProfileServerOption "the Basic Memory MCP server for omp";
            terraform = mkProfileServerOption "the Terraform MCP server for omp";
            qmd = mkProfileServerOption "the QMD MCP server for omp" // {
              url = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Optional per-profile QMD MCP URL override for omp.";
              };
            };
            deepwiki = mkProfileServerOption "the DeepWiki MCP server for omp";
            exa = mkProfileServerOption "the Exa MCP server for omp";
            openrouter-search = mkProfileServerOption "the OpenRouter Search MCP server for omp" // {
              apiKey = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Optional literal OpenRouter API key for omp.";
              };
              apiKeyFile = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Optional file containing the OpenRouter API key for omp.";
              };
              env = mkOption {
                type = types.attrsOf types.str;
                default = { };
                description = "Additional environment for the OpenRouter Search MCP server for omp.";
              };
            };
          };
        };

        env = mkOption {
          type = types.attrsOf types.str;
          default = { };
          description = ''
            Environment variables exported by the omp wrapper script.
            Use this for API keys and provider credentials
            (e.g. `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`).
            Values are rendered literally; shell expressions are not evaluated.
          '';
        };

        envFiles = mkOption {
          type = types.attrsOf types.str;
          default = { };
          description = ''
            Environment variables loaded by the omp wrapper from runtime secret
            files. Attribute names are variable names and values are literal file
            paths, for example `OPENROUTER_API_KEY = "/run/secrets/openrouter"`.
            Use this for secrets that must not be copied into the Nix store.
          '';
        };

        extraRuntimePackages = mkOption {
          type = types.listOf types.package;
          default = [ ];
          description = "Extra packages added to the omp wrapper runtime PATH.";
        };

        profiles = mkOption {
          type = types.attrsOf (
            types.submodule (
              { name, ... }:
              {
                options = {
                  enable = mkEnableOption "omp profile `${name}`" // {
                    default = true;
                  };

                  commandName = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Wrapper command name for this profile.";
                  };

                  configDir = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = ''
                      Home-relative omp config directory. Defaults to `.omp`
                      for default, `.omp-<name>` for other profiles.
                    '';
                  };

                  package = mkOption {
                    type = types.nullOr types.package;
                    default = null;
                    description = "Optional omp package override for this profile.";
                  };

                  env = mkOption {
                    type = types.attrsOf types.str;
                    default = { };
                    description = "Per-profile environment variables exported in the wrapper.";
                  };

                  envFiles = mkOption {
                    type = types.attrsOf types.str;
                    default = { };
                    description = "Per-profile environment variables loaded by the wrapper from runtime secret files.";
                  };

                  extraRuntimePackages = mkOption {
                    type = types.listOf types.package;
                    default = [ ];
                    description = "Extra packages for this profile wrapper PATH.";
                  };

                  settings = mkOption {
                    type = types.attrsOf types.anything;
                    default = { };
                    description = "Per-profile config.yml overrides.";
                  };

                  modelSettings = mkOption {
                    type = types.attrsOf types.anything;
                    default = { };
                    description = "Per-profile models.yml overrides.";
                  };

                  theme = {
                    dark = mkOption {
                      type = types.nullOr types.str;
                      default = null;
                      description = "Per-profile dark theme override.";
                    };
                    light = mkOption {
                      type = types.nullOr types.str;
                      default = null;
                      description = "Per-profile light theme override.";
                    };
                  };

                  hooks = {
                    permissionGate = {
                      enable = mkOption {
                        type = types.nullOr types.bool;
                        default = null;
                        description = "Per-profile permission gate hook override.";
                      };
                      blockedPatterns = mkOption {
                        type = types.nullOr (types.listOf permissionGatePatternType);
                        default = null;
                        description = "Per-profile permission gate regular expressions override.";
                      };
                      extraBlockedPatterns = mkOption {
                        type = types.nullOr (types.listOf permissionGatePatternType);
                        default = null;
                        description = "Additional per-profile permission gate regular expressions.";
                      };
                      blockedCommands = mkOption {
                        type = types.nullOr (types.listOf types.str);
                        default = null;
                        description = "Per-profile permission gate command names override.";
                      };
                      extraBlockedCommands = mkOption {
                        type = types.nullOr (types.listOf types.str);
                        default = null;
                        description = "Additional per-profile permission gate command names.";
                      };
                      mode = mkOption {
                        type = types.nullOr (
                          types.enum [
                            "block"
                            "ask"
                          ]
                        );
                        default = null;
                        description = "Per-profile permission gate response mode override.";
                      };
                    };
                    protectedPaths = {
                      enable = mkOption {
                        type = types.nullOr types.bool;
                        default = null;
                        description = "Per-profile protected paths hook override.";
                      };
                      globs = mkOption {
                        type = types.nullOr (types.listOf types.str);
                        default = null;
                        description = "Per-profile protected path globs override.";
                      };
                      extraGlobs = mkOption {
                        type = types.nullOr (types.listOf types.str);
                        default = null;
                        description = "Additional per-profile protected path globs.";
                      };

                      protectReads = mkOption {
                        type = types.nullOr types.bool;
                        default = null;
                        description = "Per-profile protected paths read protection override.";
                      };

                      mode = mkOption {
                        type = types.nullOr (
                          types.enum [
                            "block"
                            "ask"
                          ]
                        );
                        default = null;
                        description = "Per-profile protected paths response mode override.";
                      };
                    };

                    pathAccess = {
                      mode = mkOption {
                        type = types.nullOr (
                          types.enum [
                            "block"
                            "ask"
                            "allow"
                          ]
                        );
                        default = null;
                        description = "Per-profile path access response mode override.";
                      };
                      allowPaths = mkOption {
                        type = types.nullOr (types.listOf types.str);
                        default = null;
                        description = "Per-profile path access allowed paths override.";
                      };
                      denyPaths = mkOption {
                        type = types.nullOr (types.listOf types.str);
                        default = null;
                        description = "Per-profile path access denied paths override.";
                      };
                    };
                    custom = mkOption {
                      type = types.attrsOf types.lines;
                      default = { };
                      description = "Additional per-profile OMP ExtensionAPI hooks.";
                    };
                  };

                  mcp = {
                    enable = mkOption {
                      type = types.nullOr types.bool;
                      default = null;
                      description = "Per-profile MCP enable override.";
                    };

                    inheritGlobal = mkProfileMcpInheritGlobalOption "`tools.omp.mcp.inheritGlobal`";

                    memoryDir = mkOption {
                      type = types.nullOr types.str;
                      default = null;
                      description = "Per-profile MCP memory directory.";
                    };

                    serverOverrides = mkOption {
                      type = types.attrsOf types.anything;
                      default = { };
                      description = "Per-profile MCP server overrides.";
                    };

                    extraServers = mkOption {
                      type = types.attrsOf types.anything;
                      default = { };
                      description = "Per-profile extra MCP servers.";
                    };

                    servers = {
                      sequential-thinking = mkProfileServerOption "the sequential-thinking MCP server";
                      git = mkProfileServerOption "the git MCP server";
                      context7 = mkProfileServerOption "the Context7 MCP server";
                      nixos = mkProfileServerOption "the nixos MCP server";
                      time = mkProfileServerOption "the time MCP server";
                      fetch = mkProfileServerOption "the fetch MCP server";
                      memory = mkProfileServerOption "the memory MCP server";
                      serena = mkProfileServerOption "the serena MCP server";
                      playwright = mkProfileServerOption "the playwright MCP server";
                      filesystem = mkProfileServerOption "the filesystem MCP server";
                      notebooklm = mkProfileServerOption "the NotebookLM MCP server";
                      basic-memory = mkProfileServerOption "the Basic Memory MCP server";
                      terraform = mkProfileServerOption "the Terraform MCP server";
                      qmd = mkProfileServerOption "the QMD MCP server" // {
                        url = mkOption {
                          type = types.nullOr types.str;
                          default = null;
                          description = "Optional per-profile QMD MCP URL override.";
                        };
                      };
                      deepwiki = mkProfileServerOption "the DeepWiki MCP server";
                      exa = mkProfileServerOption "the Exa MCP server";
                      openrouter-search = mkProfileServerOption "the OpenRouter Search MCP server" // {
                        apiKey = mkOption {
                          type = types.nullOr types.str;
                          default = null;
                          description = "Optional per-profile literal OpenRouter API key override.";
                        };
                        apiKeyFile = mkOption {
                          type = types.nullOr types.str;
                          default = null;
                          description = "Optional per-profile file containing the OpenRouter API key.";
                        };
                        env = mkOption {
                          type = types.attrsOf types.str;
                          default = { };
                          description = "Additional per-profile environment for the OpenRouter Search MCP server.";
                        };
                      };
                    };
                  };
                };
              }
            )
          );
          default = { };
          description = ''
            Additional omp profiles. The default profile is always generated
            from the top-level `tools.omp.*` settings.
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
        sequential-thinking = mkServerOption "the sequential-thinking MCP server" false;
        git = mkServerOption "the git MCP server" false;
        context7 = mkServerOption "the Context7 MCP server" false;
        nixos = mkServerOption "the nixos MCP server" false;
        time = mkServerOption "the time MCP server" false;
        fetch = mkServerOption "the fetch MCP server" false;
        memory = mkServerOption "the memory MCP server" false;
        serena = mkServerOption "the serena MCP server" false;
        playwright = mkServerOption "the playwright MCP server" false;
        filesystem = mkServerOption "the filesystem MCP server" false;
        notebooklm = mkServerOption "the NotebookLM MCP server" false;
        basic-memory = mkServerOption "the Basic Memory MCP server" false;
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
        openrouter-search = mkServerOption "the OpenRouter Search MCP server" false // {
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

    disabledCommands = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Command names to exclude after category filtering. Names must match a
        known command from the discovered command groups.
      '';
    };

    disabledAgents = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Agent names to exclude after category filtering. Names must match a
        known agent from the discovered agent groups.
      '';
    };

    commands = mapAttrs (groupName: members: {
      enable = mkCollectionEnableOption "commands" groupName members;
    }) commandGroups;

    agents = mapAttrs (groupName: members: {
      enable = mkCollectionEnableOption "agents" groupName members;
    }) agentGroups;

    skills = {
      caveman.enable =
        mkEnableOption "caveman skills (caveman, caveman-commit, caveman-review, etc.)"
        // {
          default = true;
        };

      mattpocock.enable = mkEnableOption "Matt Pocock engineering and productivity skills" // {
        default = true;
      };

      superpowers.enable =
        mkEnableOption "superpowers skills (brainstorming, writing-plans, TDD, etc.)"
        // {
          default = true;
        };

      dcp.enable = mkOption {
        type = types.bool;
        default = false;
        description = "DCP (Dynamic Context Pruning) skill. Auto-enabled when any opencode profile has DCP enabled.";
      };

      karpathyGuidelines.enable = mkEnableOption "Karpathy behavioral guidelines skill" // {
        default = true;
      };

      agentBrowser.enable = mkEnableOption "agent-browser skill" // {
        default = true;
      };

      basicMemory.enable = mkOption {
        type = types.bool;
        default = false;
        description = "Basic Memory skill. Auto-enabled when the basicMemory MCP server is enabled.";
      };

      notebooklm.enable = mkOption {
        type = types.bool;
        default = false;
        description = "NotebookLM skill. Auto-enabled when the notebooklm MCP server is enabled.";
      };

      rtk.enable = mkOption {
        type = types.bool;
        default = false;
        description = "RTK (Reduce Token Karma) skill. Auto-enabled when any opencode profile has RTK enabled.";
      };

      terraform.enable = mkOption {
        type = types.bool;
        default = false;
        description = "Terraform skill from antonbabenko/terraform-skill.";
      };

      gog.enable = mkOption {
        type = types.bool;
        default = false;
        description = "gog CLI skill from openclaw/nix-openclaw-tools. Installs gogcli when enabled.";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      home.packages = packageSets.sharedAgentPackages;
      programs.git.ignores = lib.mkAfter gitIgnores;

      # Home Manager only unlinks files tracked in the previous generation, so a
      # disabled skill's dir lingers and stays discoverable; prune the known ones.
      home.activation = lib.optionalAttrs (managedSkillRoots != [ ] && orphanableSkillNames != [ ]) {
        aiToolsPruneOrphanSkills = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          for skillRoot in ${lib.escapeShellArgs managedSkillRoots}; do
            for skillName in ${lib.escapeShellArgs orphanableSkillNames}; do
              skillDir="$HOME/$skillRoot/$skillName"
              # only prune our own emitted symlinks, never a user's real skill dir
              if [ -L "$skillDir/SKILL.md" ]; then
                case "$(readlink "$skillDir/SKILL.md")" in
                  *-home-manager-files/*)
                    $DRY_RUN_CMD rm $VERBOSE_ARG -rf "$skillDir"
                    ;;
                esac
              fi
            done
          done
        '';
      };

      assertions = [
        {
          assertion = !cfg.mcp.servers.qmd.enable || qmdHasUsableDefinition;
          message = "programs.ai-tools.mcp.servers.qmd.enable requires qmd.url, mcp.serverOverrides.qmd.url, or a full local mcp.serverOverrides.qmd.command replacement.";
        }

        {
          assertion = invalidOmpEnvNames == [ ];
          message = "programs.ai-tools.tools.omp env/envFiles and profiles.* env/envFiles keys must be valid shell environment variable names. Invalid names: ${lib.concatStringsSep ", " invalidOmpEnvNames}";
        }

        {
          assertion = unknownDisabledCommands == [ ];
          message = "programs.ai-tools.disabledCommands contains unknown command names: ${lib.concatStringsSep ", " unknownDisabledCommands}";
        }

        {
          assertion = unknownDisabledAgents == [ ];
          message = "programs.ai-tools.disabledAgents contains unknown agent names: ${lib.concatStringsSep ", " unknownDisabledAgents}";
        }

      ];
    }

    (mkIf cfg.skills.agentBrowser.enable {
      home.packages = packageSets.agentBrowserSkillRuntimePackages;
    })

    (mkIf cfg.skills.caveman.enable {
      home.packages = packageSets.cavemanSkillRuntimePackages;
    })

    (mkIf cfg.skills.superpowers.enable {
      home.packages = packageSets.superpowersSkillRuntimePackages;
    })

    (mkIf cfg.skills.gog.enable {
      home.packages = packageSets.gogSkillRuntimePackages;
    })

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
          mcpServers = mkDefault (
            mkToolMcpServers "claudecode" cfg.tools.claudeCode.mcp.inheritGlobal mcp.forClaudeCode
          );
          settings = mkDefault claudeCodeSettings;
          agents = filterAgents aiTools.claudeCode.agents;
          commands = filterCommands aiTools.claudeCode.commands;
          skills = filterSkills aiTools.claudeCode.skills;
        }
        (mkIf (cfg.instructions != "") { context = mkDefault cfg.instructions; })
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
          skills = codexSkills;
        }
        (mkIf (cfg.instructions != "") { context = mkDefault cfg.instructions; })
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
          settings = mkDefault opencodeSettings;
          agents = filterAgents aiTools.opencode.agents;
          commands = filterCommands aiTools.opencode.commands;
          skills = filterSkills aiTools.claudeCode.skills;
        }
        (mkIf (cfg.instructions != "") { context = mkDefault cfg.instructions; })
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

    (mkIf cfg.tools.omp.enable {
      home.packages = ompWrapperPackages;
      home.file = lib.foldlAttrs (
        files: name: profile:
        files // mkOmpProfileFiles name profile
      ) { } enabledOmpProfiles;
    })

    (mkIf cfg.mcp.servers.notebooklm.enable {
      programs.ai-tools.skills.notebooklm.enable = mkDefault true;
    })

    (mkIf cfg.mcp.servers.basic-memory.enable {
      programs.ai-tools.skills.basicMemory.enable = mkDefault true;
    })

    (mkIf (cfg.tools.opencode.enable && opencodeRtkEnabled) {
      programs.ai-tools.skills.rtk.enable = mkDefault true;
    })

    (mkIf (cfg.tools.opencode.enable && opencodeDcpEnabled) {
      programs.ai-tools.skills.dcp.enable = mkDefault true;
    })

    # Auto-enable caveman commands when caveman skills are enabled
    (mkIf cfg.skills.caveman.enable {
      programs.ai-tools.commands.caveman.enable = mkDefault true;
    })
  ]);
}
