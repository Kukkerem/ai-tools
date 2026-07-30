{
  inputs,
  lib,
  pkgs,
}:

let
  inherit (lib)
    mapAttrs
    mapAttrsToList
    mapAttrs'
    nameValuePair
    ;

  commandGroups = import ./command-groups.nix { inherit inputs lib; };
  agentGroups = import ./agent-groups.nix { inherit lib; };
  aiCommands = import ./commands.nix { inherit inputs lib; };
  aiAgents = import ./agents.nix { inherit lib; };
  aiSkills = import ./skills.nix { inherit inputs lib pkgs; };
  aiSkillFiles = import ./skill-files.nix {
    inherit inputs lib;
    skills = aiSkills;
  };

  capitalize =
    word:
    if word == "" then
      ""
    else
      "${lib.toUpper (builtins.substring 0 1 word)}${
        builtins.substring 1 ((builtins.stringLength word) - 1) word
      }";

  humanizeName = name: lib.concatMapStringsSep " " capitalize (lib.splitString "-" name);

  escapeMultiline = value: lib.replaceStrings [ "\\" "\"" "\n" ] [ "\\\\" "\\\"" " " ] value;

  convertCommandsToGemini =
    commands:
    mapAttrs (name: prompt: {
      inherit prompt;
      description =
        let
          lines = lib.splitString "\n" prompt;
          descLine = lib.findFirst (line: lib.hasPrefix "description:" line) "" lines;
        in
        if descLine != "" then
          lib.removePrefix "description: " (lib.trim descLine)
        else
          "AI command: ${name}";
    }) commands;

  convertAgentsToGemini =
    agents:
    mapAttrs (
      name: agentText:
      let
        parts = lib.splitString "---" agentText;
        mainContent = if lib.length parts >= 3 then lib.elemAt parts 2 else agentText;
        frontmatter = if lib.length parts >= 2 then lib.elemAt parts 1 else "";
        descMatch = lib.optionals (lib.hasInfix "description:" frontmatter) [
          (lib.removePrefix "description: " (
            lib.trim (
              lib.head (lib.filter (line: lib.hasPrefix "description:" line) (lib.splitString "\n" frontmatter))
            )
          ))
        ];
        description = if descMatch != [ ] then lib.head descMatch else "AI agent: ${name}";
      in
      {
        prompt = lib.trim mainContent;
        inherit description;
      }
    ) agents;

  # Strip YAML frontmatter from a command/agent string, returning only body content
  stripFrontmatter =
    text:
    let
      parts = lib.splitString "---" text;
    in
    if lib.length parts >= 3 then lib.trim (lib.elemAt parts 2) else lib.trim text;

  # Extract a frontmatter field value by key
  extractFrontmatterField =
    key: text:
    let
      lines = lib.splitString "\n" text;
      match = lib.findFirst (line: lib.hasPrefix "${key}:" line) "" lines;
    in
    if match != "" then lib.trim (lib.removePrefix "${key}:" match) else "";

  # Render all commands as a markdown reference section for instructions.md
  renderCommandsMarkdown =
    commands:
    let
      entries = lib.mapAttrsToList (
        name: prompt:
        let
          desc = extractFrontmatterField "description" prompt;
          body = stripFrontmatter prompt;
          header = if desc != "" then "### /${name}\n> ${desc}\n" else "### /${name}\n";
        in
        "${header}\n${body}"
      ) commands;
    in
    lib.concatStringsSep "\n\n---\n\n" entries;

  # Render all agents as a markdown reference section for instructions.md
  renderAgentsMarkdown =
    agents:
    let
      entries = lib.mapAttrsToList (
        name: agentText:
        let
          desc = extractFrontmatterField "description" agentText;
          body = stripFrontmatter agentText;
          header = if desc != "" then "### Agent: ${name}\n> ${desc}\n" else "### Agent: ${name}\n";
        in
        "${header}\n${body}"
      ) agents;
    in
    lib.concatStringsSep "\n\n---\n\n" entries;

  mkSkillMetadata =
    name: sourceText:
    let
      description = extractFrontmatterField "description" sourceText;
      displayName =
        let
          explicitName = extractFrontmatterField "name" sourceText;
        in
        if explicitName != "" then explicitName else humanizeName name;
      body = stripFrontmatter sourceText;
      promptDescription =
        if description != "" then description else "specialized help for ${displayName}";
    in
    {
      inherit description displayName body;
      skillMd = ''
        ---
        name: "${name}"
        description: "${escapeMultiline promptDescription}"
        ---

        # ${displayName}

        Use this skill when you need the `${displayName}` persona for the current task.

        ${body}
      '';
      openaiYaml = ''
        interface:
          display_name: "${escapeMultiline displayName}"
          short_description: "Use the ${escapeMultiline displayName} persona"
          default_prompt: "Use $${name} for this task."
      '';
    };

  codexAgentSkills = mapAttrs mkSkillMetadata aiAgents;

  # ═══════════════════════════════════════════════════════════════
  # Per-tool metadata transformations
  #
  # Source .nix files store metadata in Claude Code frontmatter format
  # (comma-separated tools, allowed-tools, spawns, etc). Each target
  # CLI tool needs its own frontmatter dialect.
  # ═══════════════════════════════════════════════════════════════

  # Split a string by "---" markers into frontmatter and body.
  _splitFrontmatter =
    text:
    let
      parts = lib.splitString "---" text;
      hasFrontmatter = lib.length parts >= 3;
      frontmatter = if hasFrontmatter then lib.elemAt parts 1 else "";
      body =
        if hasFrontmatter then
          lib.trim (builtins.concatStringsSep "---" (lib.drop 2 parts))
        else
          lib.trim text;
    in
    {
      inherit frontmatter body;
    };

  # Parse YAML frontmatter with support for nested maps under specific keys.
  # Nested lines (indented) under keys like `tools:` are collected as:
  #   tools: "bash, read, find, search, lsp"  (comma-separated leaf values)
  # Unrecognized nested structures are dropped.
  _parseFrontmatter =
    fm:
    let
      lines = lib.filter (l: l != "") (lib.splitString "\n" fm);
      # Keys whose nested children should be collected as comma-separated values
      nestingKeys = [
        "tools"
        "permission"
      ];
      parse =
        {
          attrs,
          currentNest,
          acc,
        }:
        line:
        let
          m = builtins.match "([^:]*):(.*)" line;
          key = if m == null then null else lib.trim (builtins.elemAt m 0);
          val = if m == null then "" else lib.trim (builtins.elemAt m 1);
          isNested = line != "" && builtins.substring 0 1 line == " ";
          # Flush accumulated nested values before transitioning state
          flushedAttrs =
            if currentNest != "" && acc != [ ] then
              attrs // { ${currentNest} = lib.concatStringsSep ", " acc; }
            else
              attrs;
        in
        if isNested && currentNest != "" then
          # Indented line under a nesting key — accumulate the leaf key
          {
            inherit attrs currentNest;
            acc = acc ++ [ key ];
          }
        else if m != null && builtins.elem key nestingKeys then
          # Start of a nesting key (value may be empty or inline)
          {
            attrs = flushedAttrs;
            currentNest = key;
            acc = if val != "" then [ val ] else [ ];
          }
        else if m != null then
          # Flat key-value pair
          {
            attrs = flushedAttrs // {
              ${key} = val;
            };
            currentNest = "";
            acc = [ ];
          }
        else
          # Unrecognized line — skip
          { inherit attrs currentNest acc; };
      result = builtins.foldl' parse {
        attrs = { };
        currentNest = "";
        acc = [ ];
      } lines;
      # Fold accumulated nested values into attrs
      finalAttrs =
        if result.currentNest != "" && result.acc != [ ] then
          result.attrs // { ${result.currentNest} = lib.concatStringsSep ", " result.acc; }
        else
          result.attrs;
    in
    lib.filterAttrs (k: _: k != "") finalAttrs;

  # Convert "bash, read, write" → "permission:\n  bash: allow\n  read: allow\n"
  # with Claude Code → OpenCode permission name mapping.
  _toolsToPermissionYaml =
    toolsStr:
    let
      # Claude Code tool names → OpenCode permission names
      toolMap = {
        bash = "bash";
        read = "read";
        write = "edit";
        edit = "edit";
        find = "glob";
        search = "grep";
        lsp = "lsp";
        task = "task";
        todowrite = "todowrite";
        webfetch = "webfetch";
        websearch = "websearch";
        skill = "skill";
      };
      trimmed = lib.trim toolsStr;
      rawList = if trimmed == "" then [ ] else map lib.trim (lib.splitString "," trimmed);
      mappedList = map (tool: toolMap.${tool} or tool) rawList;
      deduped = lib.unique mappedList;
    in
    lib.concatMapStrings (tool: "  ${tool}: allow\n") deduped;

  # Rebuild a frontmatter string from an attrset (discard empty values).
  _rebuildFrontmatter =
    attrs:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (k: v: "${k}: ${v}") (lib.filterAttrs (_: v: v != "") attrs)
    );

  # ── Agent: Claude Code → OpenCode ──
  convertAgentToOpenCode =
    name: agentText:
    let
      split = _splitFrontmatter agentText;
      fm = _parseFrontmatter split.frontmatter;
      permYaml = _toolsToPermissionYaml (fm.tools or "");
      newFm = _rebuildFrontmatter {
        description = fm.description or "";
        mode = "subagent";
        permission = if permYaml == "" then "" else "\n${permYaml}";
      };
    in
    if split.frontmatter == "" then agentText else "---\n${newFm}\n---\n\n${split.body}";
  convertAgentsToOpenCode = agents: mapAttrs convertAgentToOpenCode agents;

  # ── Agent: Claude Code → omp ──
  # omp parses the frontmatter `tools:` field with `parseArrayOrCSV`, which
  # accepts an array or a CSV string and returns nothing for anything else. The
  # nested map the agents are authored with therefore reads as *absent*, so every
  # agent silently inherited omp's full default subagent toolset instead of its
  # declared one. Flatten the map into the CSV form omp expects, mapping the
  # Claude Code tool names onto omp's canonical ones.
  #
  # A present `tools:` list is also what omp treats as an explicit tool request,
  # which is the only thing that unlocks its opt-in-only subagent tools (see
  # `ompAgentExtraTools`). Note the second effect: an explicit request also keeps
  # the declared built-ins presented top-level instead of mounted under `xd://`.
  _ompToolMap = {
    find = "glob";
    search = "grep";
  };

  # omp-only tools appended per agent. They have no Claude Code or OpenCode
  # equivalent, so they must not sit in the shared agent frontmatter.
  # `checkpoint`/`rewind` are excluded from omp's default subagent toolset and
  # only become available when named explicitly (min omp 17.2.0, plus the
  # `checkpoint.enabled` master toggle). omp silently filters any requested tool
  # that is unknown or not permitted at subagent depth, so listing these ahead of
  # a version bump is inert rather than an error. Granted to the
  # investigate-and-report agents, whose long tool-output transcripts are what
  # checkpoint/rewind exist to compress.
  ompAgentExtraTools = {
    code-reviewer = [
      "checkpoint"
      "rewind"
    ];
    nix-builder = [
      "checkpoint"
      "rewind"
    ];
    nix-linter = [
      "checkpoint"
      "rewind"
    ];
    security-auditor = [
      "checkpoint"
      "rewind"
    ];
  };

  convertAgentToOmp =
    name: agentText:
    let
      split = _splitFrontmatter agentText;
      fm = _parseFrontmatter split.frontmatter;
      declaredStr = lib.trim (fm.tools or "");
      declared = if declaredStr == "" then [ ] else map lib.trim (lib.splitString "," declaredStr);
      mapped = map (tool: _ompToolMap.${tool} or tool) declared;
      tools = lib.unique (mapped ++ (ompAgentExtraTools.${name} or [ ]));
      # An agent that declares no tools keeps omp's default toolset: an empty
      # value is dropped by _rebuildFrontmatter rather than emitted as `tools:`.
      newFm = _rebuildFrontmatter (fm // { tools = lib.concatStringsSep ", " tools; });
    in
    if split.frontmatter == "" then agentText else "---\n${newFm}\n---\n\n${split.body}";
  convertAgentsToOmp = agents: mapAttrs convertAgentToOmp agents;

  # ── Command: Claude Code → OpenCode ──
  convertCommandToOpenCode =
    name: cmdText:
    let
      split = _splitFrontmatter cmdText;
      fm = _parseFrontmatter split.frontmatter;
      newFm = _rebuildFrontmatter { description = fm.description or ""; };
    in
    if split.frontmatter == "" then cmdText else "---\n${newFm}\n---\n\n${split.body}";

  convertCommandsToOpenCode = commands: mapAttrs convertCommandToOpenCode commands;

  # ── Command: Claude Code → Codex ──
  convertCommandToCodex =
    name: cmdText:
    let
      split = _splitFrontmatter cmdText;
      fm = _parseFrontmatter split.frontmatter;
      newFm = _rebuildFrontmatter {
        description = fm.description or "";
        argument-hint = fm.argument-hint or "";
      };
    in
    if split.frontmatter == "" then cmdText else "---\n${newFm}\n---\n\n${split.body}";

  convertCommandsToCodex = commands: mapAttrs convertCommandToCodex commands;

in
{
  inherit commandGroups agentGroups;

  claudeCode = {
    commands = aiCommands;
    agents = aiAgents;
    skills = aiSkills;
    skillFiles = aiSkillFiles;
  };

  geminiCli = {
    commands = convertCommandsToGemini aiCommands;
    agents = convertAgentsToGemini aiAgents;
    skills = aiSkills;
    skillFiles = aiSkillFiles;
  };

  # Codex uses a single instructions.md + skills path references.
  # Prompts are transformed to Codex-compatible frontmatter (description + argument-hint only).
  codex = {
    commandsMarkdown = renderCommandsMarkdown aiCommands;
    agentsMarkdown = renderAgentsMarkdown aiAgents;
    prompts = convertCommandsToCodex aiCommands;
    skills = aiSkills;
    skillFiles = aiSkillFiles;
    agentSkills = codexAgentSkills;
  };

  # omp discovers skills/agents/commands via filesystem under
  # .omp/{skills,agents,commands}/, with the same Markdown structure
  # as claude-code. Commands need no conversion; agents do, because omp's
  # frontmatter `tools:` parser accepts only an array or a CSV string and
  # silently ignores the nested map form (see convertAgentToOmp).
  omp = {
    commands = aiCommands;
    agents = convertAgentsToOmp aiAgents;
    skills = aiSkills;
    skillFiles = aiSkillFiles;
  };

  # opencode agents/commands use OpenCode's YAML frontmatter format
  # (tools as YAML map, mode: subagent, no spawns/allowed-tools).
  opencode = {
    agents = convertAgentsToOpenCode aiAgents;
    commands = convertCommandsToOpenCode aiCommands;
  };

  mergeCommands = existingCommands: newCommands: existingCommands // newCommands;
}
