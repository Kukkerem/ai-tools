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
in
pkgs.runCommand "ai-tools-home-manager-tests" { nativeBuildInputs = [ pkgs.jq ]; } ''
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

  touch $out
''
