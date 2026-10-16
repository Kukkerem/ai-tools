{
  inputs,
  lib,
  pkgs,
}:

let
  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};

  toTomlBool = b: if b then "true" else "false";
  toTomlList = xs: "[${lib.concatMapStringsSep ", " (x: "\"${x}\"") xs}]";

  mkRtkConfig =
    {
      excludeCommands ? [ ],
      teeEnable ? true,
      teeMode ? "failures",
      telemetryEnable ? false,
    }:
    ''
      [hooks]
      exclude_commands = ${toTomlList excludeCommands}

      [tee]
      enabled = ${toTomlBool teeEnable}
      mode = "${teeMode}"

      [telemetry]
      enabled = ${toTomlBool telemetryEnable}
    '';

  protectedTools = [
    "task_*"
    "memory_*"
    "session_*"
    "serena_*"
    "notebooklm_*"
    "basic_memory_*"
  ];
in
{
  # Native OpenCode V2 `opencode.jsonc` defaults. Permission rules are ordered
  # and the last matching rule wins, so caller `permissions` override defaults.
  defaultSettings =
    {
      permissions ? [ ],
      plugins ? [ ],
      smallModel ? "openrouter/openai/gpt-5-nano",
      disabledProviders ? [ "github-copilot" ],
    }:
    {
      "$schema" = "https://opencode.ai/config.json";
      inherit plugins;
      share = "manual";
      update = "auto";
      permissions = [
        {
          action = "shell";
          resource = "*";
          effect = "ask";
        }
        {
          action = "edit";
          resource = "*";
          effect = "ask";
        }
        {
          action = "webfetch";
          resource = "*";
          effect = "allow";
        }
        # V2 allows paths outside the project by default; V1 asked.
        {
          action = "external_directory";
          resource = "*";
          effect = "ask";
        }
      ]
      ++ permissions;
      policies = map (provider: {
        action = "provider.use";
        resource = provider;
        effect = "deny";
      }) disabledProviders;
      # V2 replaces `small_model` with the built-in `title` agent's model.
      agents.title.model = smallModel;
      formatter.nixfmt = {
        command = [
          (lib.getExe pkgs.nixfmt)
          "$FILE"
        ];
        extensions = [ ".nix" ];
      };
    };

  dcpConfig = {
    "$schema" =
      "https://raw.githubusercontent.com/Opencode-DCP/opencode-dynamic-context-pruning/master/dcp.schema.json";

    turnProtection = {
      enabled = true;
      turns = 4;
    };

    compress = {
      mode = "range";
      minContextLimit = 50000;
      maxContextLimit = 100000;
      protectUserMessages = true;
      inherit protectedTools;
    };
    commands = {
      inherit protectedTools;
    };
    strategies = {
      deduplication = {
        inherit protectedTools;
      };
      purgeErrors = {
        turns = 4;
        inherit protectedTools;
      };
    };
  };

  # Default config with sane values
  rtkConfig = mkRtkConfig { };

  inherit mkRtkConfig;

  rtkPackage = pkgs.writeShellApplication {
    name = "rtk";
    runtimeInputs = [ llmAgents.rtk ];
    text = ''
      export LC_ALL=C
      exec ${lib.getExe llmAgents.rtk} "$@"
    '';
  };

  # Upstream OpenCode plugin shipped with rtk. Its default export carries both
  # the V2 `setup` entrypoint and the V1 `server` one; rewrite and permission
  # logic lives in `rtk hook opencode`, so the plugin must match the rtk binary.
  rtkPluginSource = "${llmAgents.rtk.src}/hooks/opencode/rtk.ts";
}
