{
  aiToolsModule,
  inputs,
  lib,
  pkgs,
}:

let
  generation =
    (inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        aiToolsModule
        {
          home.username = "tester";
          home.homeDirectory = "/home/tester";
          home.stateVersion = "25.05";

          programs.ai-tools = {
            enable = true;
            tools.opencode = {
              enable = true;
              profiles.work = {
                commandName = "ocw";
                runCommandName = "ocw-run";
                configDir = ".config/opencode-work";
                dataDir = ".local/share/opencode-work";
                stateDir = ".local/state/opencode-work";
                theme = "nightowl";
                extraRuntimePackages = [ pkgs.hello ];
                extraFiles."plugin-config.jsonc".value = {
                  enabled = true;
                  nested.option = "value";
                };
                mcp = {
                  memoryDir = "opencode-work";
                  servers = {
                    context7.enable = false;
                    openrouterSearch = {
                      enable = true;
                      apiKeyFile = "/run/secrets/openrouter-work-api-key";
                    };
                  };
                  extraServers.cloudflare-docs.url = "https://docs.mcp.cloudflare.com/mcp";
                };
              };
            };
            tools.omp = {
              enable = true;
              mcp.memoryDir = "custom-omp";
              profiles.work = {
                commandName = "ompw";
                configDir = ".omp-work";
                env = {
                  ANTHROPIC_API_KEY = "test key with spaces";
                  SHELL_TEST = "value with \"quotes\" and $dollar";
                };
                settings.autoResume = true;
                modelSettings.modelRoles.default = "openai/gpt-4o";
                hooks.permissionGate.enable = false;
                mcp = {
                  memoryDir = "omp-work";
                  servers.context7.enable = true;
                };
              };
            };
            mcp = {
              servers = {
                context7.enable = true;
                memory.enable = true;
              };
            };
          };
        }
      ];
    }).activationPackage;

  runtimeGeneration =
    (inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        aiToolsModule
        {
          home.username = "tester";
          home.homeDirectory = "/home/tester";
          home.stateVersion = "25.05";

          programs.ai-tools = {
            enable = true;
            skills = {
              agentBrowser.enable = true;
              caveman.enable = true;
              superpowers.enable = true;
            };
          };
        }
      ];
    }).activationPackage;

  disabledSkillsGeneration =
    (inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        aiToolsModule
        {
          home.username = "tester";
          home.homeDirectory = "/home/tester";
          home.stateVersion = "25.05";

          programs.ai-tools = {
            enable = true;
            tools.omp.enable = true;
            skills.mattpocock.enable = false;
          };
        }
      ];
    }).activationPackage;
in
pkgs.runCommand "ai-tools-home-manager-tests"
  {
    nativeBuildInputs = [
      pkgs.jq
      pkgs.yq-go
    ];
  }
  ''
    default_config=${generation}/home-files/.config/opencode/opencode.json
    work_config=${generation}/home-files/.config/opencode-work/opencode.jsonc
    work_plugin_config=${generation}/home-files/.config/opencode-work/plugin-config.jsonc
    work_wrapper=${generation}/home-path/bin/ocw
    work_run_wrapper=${generation}/home-path/bin/ocw-run

    test -f "$default_config"
    test -f "$work_config"
    test -f "$work_plugin_config"
    test -x "$work_wrapper"
    test -x "$work_run_wrapper"

    jq -e '.theme == "catppuccin"' "$default_config" >/dev/null
    jq -e '.mcp.context7.enabled == true' "$default_config" >/dev/null
    jq -e '.mcp.memory.environment.MEMORY_FILE_PATH == "/home/tester/.cache/ai-tools/default-opencode/memory.json"' "$default_config" >/dev/null

    jq -e '.theme == "nightowl"' "$work_config" >/dev/null
    jq -e '.mcp.context7 == null' "$work_config" >/dev/null
    jq -e '.mcp."cloudflare-docs".url == "https://docs.mcp.cloudflare.com/mcp"' "$work_config" >/dev/null
    jq -e '.mcp."openrouter-search".environment.OPENROUTER_API_KEY_FILE == "/run/secrets/openrouter-work-api-key"' "$work_config" >/dev/null
    jq -e '.mcp.memory.environment.MEMORY_FILE_PATH == "/home/tester/.cache/ai-tools/opencode-work/memory.json"' "$work_config" >/dev/null

    jq -e '.enabled == true' "$work_plugin_config" >/dev/null
    jq -e '.nested.option == "value"' "$work_plugin_config" >/dev/null

    grep -F 'export OPENCODE_CONFIG="$HOME/.config/opencode-work/opencode.jsonc"' "$work_wrapper" >/dev/null
    grep -F 'export OPENCODE_CONFIG_DIR="$HOME/.config/opencode-work"' "$work_wrapper" >/dev/null
    grep -F 'export XDG_DATA_HOME="$HOME/.local/share/opencode-work"' "$work_wrapper" >/dev/null
    grep -F 'export XDG_STATE_HOME="$HOME/.local/state/opencode-work"' "$work_wrapper" >/dev/null
    grep -F '${pkgs.hello}/bin' "$work_wrapper" >/dev/null
    grep -F ' run "$@"' "$work_run_wrapper" >/dev/null

    # ── omp tests ──

    omp_default_config=${generation}/home-files/.omp/agent/config.yml
    omp_default_models=${generation}/home-files/.omp/agent/models.yml
    omp_default_mcp=${generation}/home-files/.omp/agent/mcp.json
    omp_wrapper=${generation}/home-path/bin/omp
    omp_perm_gate=${generation}/home-files/.omp/agent/extensions/permission-gate.ts
    omp_agent_browser_reference=${generation}/home-files/.omp/agent/skills/agent-browser/references/commands.md
    omp_caveman_compress_script=${generation}/home-files/.omp/agent/skills/caveman-compress/scripts/compress.py
    omp_tdd_skill=${generation}/home-files/.omp/agent/skills/tdd/SKILL.md
    omp_prototype_logic=${generation}/home-files/.omp/agent/skills/prototype/LOGIC.md
    omp_old_tdd_skill=${generation}/home-files/.omp/skills/tdd/SKILL.md

    test -f "$omp_default_config"
    test -f "$omp_default_models"
    test -f "$omp_default_mcp"
    test -x "$omp_wrapper"
    test -f "$omp_perm_gate"
    test -f "$omp_agent_browser_reference"
    test -f "$omp_caveman_compress_script"
    test -f "$omp_tdd_skill"
    test -f "$omp_prototype_logic"
    test ! -e "$omp_old_tdd_skill"

    test -x ${runtimeGeneration}/home-path/bin/python3
    test -x ${runtimeGeneration}/home-path/bin/node
    test -x ${runtimeGeneration}/home-path/bin/dot
    test -x ${runtimeGeneration}/home-path/bin/which
    test -x ${runtimeGeneration}/home-path/bin/find
    test -x ${runtimeGeneration}/home-path/bin/chromium

    test "$(yq '.theme.dark' $omp_default_config)" = "titanium"
    test "$(yq '.compaction.enabled' $omp_default_config)" = "true"
    test "$(yq '.compaction.reserveTokens' $omp_default_config)" = "16384"
    test "$(yq '.defaultThinkingLevel' $omp_default_config)" = "high"
    test "$(yq '.modelRoles.default' $omp_default_models)" = "claude-sonnet-4-6"
    test "$(yq '.modelProviderOrder[0]' $omp_default_models)" = "anthropic"
    jq -e '.mcpServers.memory.env.MEMORY_FILE_PATH == "/home/tester/.cache/ai-tools/custom-omp/memory.json"' "$omp_default_mcp" >/dev/null

    grep -F 'export PI_CONFIG_DIR="$HOME"/.omp' "$omp_wrapper" >/dev/null

    # ── omp work profile tests ──

    omp_work_config=${generation}/home-files/.omp-work/agent/config.yml
    omp_work_models=${generation}/home-files/.omp-work/agent/models.yml
    omp_work_wrapper=${generation}/home-path/bin/ompw
    omp_work_perm_gate=${generation}/home-files/.omp-work/agent/extensions/permission-gate.ts
    omp_work_mcp=${generation}/home-files/.omp-work/agent/mcp.json

    test -f "$omp_work_config"
    test -f "$omp_work_models"
    test -x "$omp_work_wrapper"

    test "$(yq '.autoResume' $omp_work_config)" = "true"
    test "$(yq '.modelRoles.default' $omp_work_models)" = "openai/gpt-4o"

    grep -F 'export PI_CONFIG_DIR="$HOME"/.omp-work' "$omp_work_wrapper" >/dev/null
    grep -F "export ANTHROPIC_API_KEY='test key with spaces'" "$omp_work_wrapper" >/dev/null
    grep -F 'export SHELL_TEST=' "$omp_work_wrapper" >/dev/null
    grep -F 'value with "quotes" and $dollar' "$omp_work_wrapper" >/dev/null

    # permission gate disabled in work profile
    test ! -f "$omp_work_perm_gate"

    jq -e '.mcpServers.memory.env.MEMORY_FILE_PATH == "/home/tester/.cache/ai-tools/omp-work/memory.json"' "$omp_work_mcp" >/dev/null
    jq -e '.mcpServers.context7 != null' "$omp_work_mcp" >/dev/null

    # Matt Pocock repo skills can be disabled as a category.
    test ! -e ${disabledSkillsGeneration}/home-files/.omp/agent/skills/tdd/SKILL.md

    touch $out
  ''
