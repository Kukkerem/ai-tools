{
  inputs,
  lib,
  pkgs,
}:

let
  mcp = import ../lib/mcp.nix { inherit inputs lib pkgs; };
  opencode = import ../lib/opencode.nix { inherit inputs lib pkgs; };

  aiTools = import ../ai-tools { inherit inputs lib pkgs; };

  omp = import ../lib/omp.nix { inherit inputs lib pkgs; };

  protectedPathsRuntimeHook = pkgs.writeText "protected-paths-runtime.ts" (
    omp.mkProtectedPathsHook { mode = "ask"; }
  );
  pathAccessRuntimeHook = pkgs.writeText "path-access-runtime.ts" (
    omp.mkPathAccessHook {
      mode = "ask";
      allowPaths = [ ];
      denyPaths = [ ];
    }
  );
  hookRuntimeTests = pkgs.writeText "omp-hook-runtime-tests.ts" ''
    import protectedPaths from "${protectedPathsRuntimeHook}";
    import pathAccess from "${pathAccessRuntimeHook}";

    type ToolCall = { toolName: string; input?: Record<string, unknown> };
    type Handler = (call: ToolCall, ctx: any) => Promise<any> | any;

    function assert(condition: unknown, message: string): void {
      if (!condition) throw new Error(message);
    }

    function register(extension: (pi: any) => void): Handler {
      let handler: Handler | undefined;
      extension({
        on(name: string, fn: Handler) {
          if (name !== "tool_call") throw new Error("unexpected event " + name);
          handler = fn;
        },
      });
      if (!handler) throw new Error("extension did not register tool_call");
      return handler;
    }

    function uiRecorder(choice: string) {
      const calls: Array<{ title: string; options: string[] }> = [];
      return {
        calls,
        ctx: {
          hasUI: true,
          ui: {
            select(title: string, options: string[]) {
              assert(arguments.length === 2, "select must be called with title and options only");
              assert(Array.isArray(options), "select options must be an array");
              assert(options.every((option) => typeof option === "string"), "select options must be strings");
              calls.push({ title, options });
              return choice;
            },
          },
        },
      };
    }

    const protectedHandler = register(protectedPaths);

    {
      const ui = uiRecorder("Allow once");
      const result = await protectedHandler({ toolName: "read", input: { path: ".env.local" } }, ui.ctx);
      assert(result === undefined, ".env.local should be allowed once after prompt");
      assert(ui.calls.length === 1, ".env.local should prompt as protected path");
    }

    {
      const ui = uiRecorder("Allow once");
      const result = await protectedHandler({
        toolName: "read",
        input: { path: process.cwd() + "/.env" },
      }, ui.ctx);
      assert(result === undefined, "absolute workspace .env should be allowed once after prompt");
      assert(ui.calls.length === 1, "absolute workspace .env should prompt as protected path");
    }

    {
      const ui = uiRecorder("Allow once");
      const result = await protectedHandler({
        toolName: "read",
        input: { path: "/tmp/project/.git/config" },
      }, ui.ctx);
      assert(result === undefined, "absolute .git path should be allowed once after prompt");
      assert(ui.calls.length === 1, "absolute .git path should prompt as protected path");
    }

    {
      const ui = uiRecorder("Allow once");
      const result = await protectedHandler({
        toolName: "read",
        input: { path: "/tmp/project/.direnv/flake-profile" },
      }, ui.ctx);
      assert(result === undefined, "absolute .direnv path should be allowed once after prompt");
      assert(ui.calls.length === 1, "absolute .direnv path should prompt as protected path");
    }

    {
      const ui = uiRecorder("Allow once");
      const result = await protectedHandler({ toolName: "search", input: { pattern: ".env" } }, ui.ctx);
      assert(result === undefined, "search pattern alone should not be treated as a path");
      assert(ui.calls.length === 0, "search pattern alone should not prompt");
    }

    const pathAccessHandler = register(pathAccess);

    {
      const ui = uiRecorder("Allow once");
      const result = await pathAccessHandler({ toolName: "grep", input: { path: "/tmp/outside" } }, ui.ctx);
      assert(result === undefined, "grep outside workspace should be allowed once after prompt");
      assert(ui.calls.length === 1, "grep outside workspace should prompt");
    }

    {
      const ui = uiRecorder("Allow once");
      const result = await pathAccessHandler({ toolName: "search", input: { pattern: "/tmp/outside" } }, ui.ctx);
      assert(result === undefined, "search pattern alone should not be treated as an outside path");
      assert(ui.calls.length === 0, "search pattern alone should not prompt for path access");
    }
  '';

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
        builtins.match ".*loadGrants.*saveGrant.*sessionGrants.*" (
          omp.mkGrantsHelper { grantNamespace = "test"; }
        ) != null;
      expected = true;
    };

    testPathAccessHookContainsWorkspaceCheck = {
      expr =
        let
          omp = import ../lib/omp.nix { inherit inputs lib pkgs; };
          hook = omp.mkPathAccessHook {
            mode = "ask";
            allowPaths = [ "/nix/store" ];
            denyPaths = [ "~/.ssh" ];
          };
        in
        builtins.match ".*isInsideWorkspace.*ALLOW_PATHS.*DENY_PATHS.*checkGrant.*" hook != null;
      expected = true;
    };

    testPathAccessHookBlockMode = {
      expr =
        let
          omp = import ../lib/omp.nix { inherit inputs lib pkgs; };
          hook = omp.mkPathAccessHook {
            mode = "block";
            allowPaths = [ ];
            denyPaths = [ ];
          };
        in
        builtins.match ".*block: true.*" hook != null
        && builtins.match ".*ctx\\.ui\\.confirm.*" hook == null;
      expected = true;
    };

    testProtectedPathsProtectReadsIncludesReadTools = {
      expr =
        let
          omp = import ../lib/omp.nix { inherit inputs lib pkgs; };
          hook = omp.mkProtectedPathsHook { protectReads = true; };
        in
        builtins.match ".*call\\.toolName !== \"read\".*" hook != null;
      expected = true;
    };

    testProtectedPathsNoReadProtectionExcludesReadTools = {
      expr =
        let
          omp = import ../lib/omp.nix { inherit inputs lib pkgs; };
          hook = omp.mkProtectedPathsHook { protectReads = false; };
        in
        builtins.match ".*call\\.toolName !== \"read\".*" hook == null;
      expected = true;
    };

    testProtectedPathsAskModePromptsWithGrants = {
      expr =
        let
          omp = import ../lib/omp.nix { inherit inputs lib pkgs; };
          hook = omp.mkProtectedPathsHook { mode = "ask"; };
        in
        builtins.match ".*checkGrant\\(fp\\).*ctx\\.ui\\.select.*Allow for session.*saveGrant\\(fp, scope\\).*" hook
        != null;
      expected = true;
    };

    testProtectedPathsBlockModeDoesNotPrompt = {
      expr =
        let
          omp = import ../lib/omp.nix { inherit inputs lib pkgs; };
          hook = omp.mkProtectedPathsHook { mode = "block"; };
        in
        builtins.match ".*block: true.*Protected path:.*" hook != null
        && builtins.match ".*ctx\\.ui\\.select.*" hook == null;
      expected = true;
    };

    testPermissionGateDefaultsIncludePiGuardrailsCommands = {
      expr =
        let
          omp = import ../lib/omp.nix { inherit inputs lib pkgs; };
          patternTexts = map (pattern: pattern.pattern) omp.defaultPermissionGateBlockedPatterns;
        in
        lib.all (pattern: builtins.elem pattern patternTexts) [
          "\\bbrew\\b"
          "\\bdocker\\s+inspect\\b"
          "\\bterraform\\s+apply\\b"
          "\\bterraform\\s+destroy\\b"
          "\\bkubectl\\s+delete\\b"
          "\\bdocker\\s+system\\s+prune\\b"
          "\\bnpm\\s+publish\\b"
          "\\byarn\\s+publish\\b"
          "\\bpnpm\\s+publish\\b"
          "\\bDROP\\s+DATABASE\\b"
          "\\bDROP\\s+TABLE\\b"
          "\\bdbt\\s+run\\b"
          "\\bdbt\\s+seed\\b"
          "\\baws\\s+s3\\s+rm\\b"
          "\\baws\\s+iam\\b"
          "\\baws\\s+ec2\\s+terminate-instances\\b"
          "\\bkubectl\\s+apply\\b"
          "\\bkubectl\\s+scale\\b"
          "\\bdocker\\s+rm\\b"
          "\\bdocker\\s+rmi\\b"
          "\\bdocker\\s+compose\\s+down\\b"
          "\\bterraform\\s+import\\b"
          "\\bgcloud\\s+compute\\s+instances\\s+delete\\b"
          "\\bgcloud\\s+iam\\b"
          "\\bgcloud\\s+sql\\s+instances\\s+delete\\b"
        ];
      expected = true;
    };

    testPermissionGateAskModeHasSessionGrants = {
      expr =
        let
          omp = import ../lib/omp.nix { inherit inputs lib pkgs; };
          hook = omp.mkPermissionGateHook { mode = "ask"; };
        in
        builtins.match ".*saveGrant.*checkGrant.*Allow for session.*Always allow.*" hook != null;
      expected = true;
    };

    testPermissionGateBlockModeNoGrants = {
      expr =
        let
          omp = import ../lib/omp.nix { inherit inputs lib pkgs; };
          hook = omp.mkPermissionGateHook { mode = "block"; };
        in
        builtins.match ".*saveGrant.*" hook != null;
      expected = false;
    };

    testPermissionGateAskChecksGrantBeforeNoUi = {
      expr =
        let
          omp = import ../lib/omp.nix { inherit inputs lib pkgs; };
          hook = omp.mkPermissionGateHook { mode = "ask"; };
        in
        builtins.match ".*var grant = checkGrant\\(command\\).*if \\(!ctx\\.hasUI\\).*var cmdGrant = checkGrant\\(firstWord\\).*if \\(!ctx\\.hasUI\\).*" hook
        != null;
      expected = true;
    };

    testPathAccessAllowModeDoesNotBlockOutsideWorkspace = {
      expr =
        let
          omp = import ../lib/omp.nix { inherit inputs lib pkgs; };
          hook = omp.mkPathAccessHook {
            mode = "allow";
            allowPaths = [ ];
            denyPaths = [ ];
          };
        in
        builtins.match ".*Path access blocked:.*" hook == null
        && builtins.match ".*ctx\\.ui\\.select.*" hook == null;
      expected = true;
    };

    testPathAccessAllowPathsRequireExactDirectoryBoundary = {
      expr =
        let
          omp = import ../lib/omp.nix { inherit inputs lib pkgs; };
          hook = omp.mkPathAccessHook {
            allowPaths = [ "/nix/store" ];
            denyPaths = [ ];
          };
        in
        builtins.match ".*fp === allowPath \\|\\| fp\\.startsWith\\(allowPath \\+ \"/\"\\).*" hook != null;
      expected = true;
    };

    testPathAccessNormalizesRelativePathsBeforePolicy = {
      expr =
        let
          omp = import ../lib/omp.nix { inherit inputs lib pkgs; };
          hook = omp.mkPathAccessHook { };
        in
        builtins.match ".*path\\.resolve\\(process\\.cwd\\(\\), fp\\).*" hook != null;
      expected = true;
    };
  };
in
assert failures == [ ];
pkgs.runCommand "ai-tools-lib-tests" { nativeBuildInputs = [ pkgs.bun ]; } ''
  bun ${hookRuntimeTests}
  touch $out
''
