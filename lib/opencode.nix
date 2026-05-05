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
  defaultSettings =
    {
      nixdInitialization,
      permission ? { },
      plugins ? [ ],
      theme ? "catppuccin",
      smallModel ? "openrouter/openai/gpt-5-nano",
      disabledProviders ? [ "github-copilot" ],
      # Per-LSP enable toggles. Each defaults to true.
      lspBashls ? true,
      lspPyright ? true,
      lspNixd ? true,
      lspTerraformls ? true,
      lspGopls ? true,
      lspYamlls ? true,
      lspJsonls ? true,
    }:
    let
      allLsp = {
        bashls = lib.optionalAttrs lspBashls {
          command = [
            (lib.getExe pkgs.bash-language-server)
            "start"
          ];
          extensions = [
            ".sh"
            ".bash"
          ];
        };
        pyright = lib.optionalAttrs lspPyright {
          command = [ (lib.getExe pkgs.pyright) ];
          extensions = [
            ".py"
            ".pyi"
          ];
        };
        nixd = lib.optionalAttrs lspNixd {
          command = [ (lib.getExe pkgs.nixd) ];
          extensions = [ ".nix" ];
          initialization = nixdInitialization;
        };
        terraformls = lib.optionalAttrs lspTerraformls {
          command = [
            (lib.getExe pkgs.terraform-ls)
            "serve"
          ];
          extensions = [
            ".tf"
            ".tfvars"
          ];
        };
        gopls = lib.optionalAttrs lspGopls {
          command = [ (lib.getExe pkgs.gopls) ];
          extensions = [
            ".go"
            ".mod"
            ".sum"
          ];
        };
        yamlls = lib.optionalAttrs lspYamlls {
          command = [
            (lib.getExe pkgs.yaml-language-server)
            "--stdio"
          ];
          extensions = [
            ".yaml"
            ".yml"
          ];
        };
        jsonls = lib.optionalAttrs lspJsonls {
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
      # Remove LSP entries whose value is {} (disabled via optionalAttrs false)
      enabledLsp = lib.filterAttrs (_: v: v != { }) allLsp;
    in
    {
      plugin = plugins;
      inherit theme;
      share = "manual";
      autoshare = false;
      autoupdate = true;
      disabled_providers = disabledProviders;
      small_model = smallModel;
      permission = {
        bash = "ask";
        edit = "ask";
        webfetch = "allow";
      }
      // permission;
      formatter.nixfmt = {
        command = [
          (lib.getExe pkgs.nixfmt)
          "$FILE"
        ];
        extensions = [ ".nix" ];
      };
      lsp = enabledLsp;
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

  rtkPlugin = ''
    import type { Plugin } from "@opencode-ai/plugin"

    export const RtkOpenCodePlugin: Plugin = async ({ $ }) => {
      try {
        await $`which rtk`.quiet()
      } catch {
        console.warn("[rtk] rtk binary not found in PATH - plugin disabled")
        return {}
      }

      return {
        "tool.execute.before": async (input, output) => {
          const tool = String(input?.tool ?? "").toLowerCase()
          if (tool !== "bash" && tool !== "shell") return
          const args = output?.args
          if (!args || typeof args !== "object") return

          const command = (args as Record<string, unknown>).command
          if (typeof command !== "string" || !command) return

          try {
            const result = await $`rtk rewrite ''${command}`.quiet().nothrow()
            const rewritten = String(result.stdout).trim()
            if (rewritten && rewritten !== command) {
              ;(args as Record<string, unknown>).command = rewritten
            }
          } catch {
            // rtk rewrite failed - pass through unchanged
          }
        },
      }
    }
  '';
}
