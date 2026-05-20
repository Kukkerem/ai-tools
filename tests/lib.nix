{
  inputs,
  lib,
  pkgs,
}:

let
  mcp = import ../lib/mcp.nix { inherit inputs lib pkgs; };
  opencode = import ../lib/opencode.nix { inherit inputs lib pkgs; };

  aiTools = import ../ai-tools { inherit inputs lib pkgs; };

  failures = lib.debug.runTests {
    testCommandGroupsFlattenToClaudeCommands = {
      expr = lib.foldl' lib.recursiveUpdate { } (builtins.attrValues aiTools.commandGroups);
      expected = aiTools.claudeCode.commands;
    };

    testAgentGroupsFlattenToClaudeAgents = {
      expr = lib.foldl' lib.recursiveUpdate { } (builtins.attrValues aiTools.agentGroups);
      expected = aiTools.claudeCode.agents;
    };

    testRtkConfigRendersToml = {
      expr = opencode.mkRtkConfig {
        excludeCommands = [
          "cat"
          "nix flake metadata"
        ];
        teeEnable = false;
        teeMode = "all";
        telemetryEnable = true;
      };
      expected = ''
        [hooks]
        exclude_commands = ["cat", "nix flake metadata"]

        [tee]
        enabled = false
        mode = "all"

        [telemetry]
        enabled = true
      '';
    };

    testOpenCodeMcpTransformsLocalServer = {
      expr =
        (mcp.forOpenCode {
          enabledServerNames = [ "filesystem" ];
          filesystemAllowedPaths = [ "/tmp/project" ];
          memoryBaseDir = "/tmp/state";
          memoryDir = "profile";
        }).filesystem.type;
      expected = "local";
    };

    testOpenCodeMcpUsesProfileMemory = {
      expr =
        (mcp.forOpenCode {
          enabledServerNames = [ "memory" ];
          filesystemAllowedPaths = [ "/tmp/project" ];
          memoryBaseDir = "/tmp/state";
          memoryDir = "profile";
        }).memory.environment.MEMORY_FILE_PATH;
      expected = "/tmp/state/profile/memory.json";
    };

    testOpenCodeMcpOpenRouterSecretFile = {
      expr =
        (mcp.forOpenCode {
          enabledServerNames = [ "openrouter-search" ];
          filesystemAllowedPaths = [ "/tmp/project" ];
          memoryBaseDir = "/tmp/state";
          memoryDir = "profile";
          openrouterSearchApiKeyFile = "/run/secrets/openrouter";
        }).openrouter-search.environment.OPENROUTER_API_KEY_FILE;
      expected = "/run/secrets/openrouter";
    };

    testOpenCodeMcpExtraServerRemote = {
      expr =
        (mcp.forOpenCode {
          enabledServerNames = [ ];
          filesystemAllowedPaths = [ "/tmp/project" ];
          memoryBaseDir = "/tmp/state";
          memoryDir = "profile";
          extraServers.docs.url = "https://docs.example.test/mcp";
        }).docs;
      expected = {
        type = "remote";
        enabled = true;
        url = "https://docs.example.test/mcp";
      };
    };

    testGrantsHelperContainsLoadAndSave = {
      expr =
        let
          omp = import ../lib/omp.nix { inherit inputs lib pkgs; };
        in
        builtins.match ".*loadGrants.*saveGrant.*sessionGrants.*" (omp.mkGrantsHelper { grantNamespace = "test"; }) != null;
      expected = true;
    };

    testPathAccessHookContainsWorkspaceCheck = {
      expr =
        let
          omp = import ../lib/omp.nix { inherit inputs lib pkgs; };
          hook = omp.mkPathAccessHook { mode = "ask"; allowPaths = [ "/nix/store" ]; denyPaths = [ "~/.ssh" ]; };
        in
        builtins.match ".*isInsideWorkspace.*ALLOW_PATHS.*DENY_PATHS.*checkGrant.*" hook != null;
      expected = true;
    };

    testPathAccessHookBlockMode = {
      expr =
        let
          omp = import ../lib/omp.nix { inherit inputs lib pkgs; };
          hook = omp.mkPathAccessHook { mode = "block"; allowPaths = []; denyPaths = []; };
        in
        builtins.match ".*block: true.*" hook != null && builtins.match ".*ctx\\.ui\\.confirm.*" hook == null;
      expected = true;
    };
  };
in
assert failures == [ ];
pkgs.runCommand "ai-tools-lib-tests" { } ''
  touch $out
''
