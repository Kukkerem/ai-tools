# OMP Sandboxing Phase 1: In-Process Policy Hooks

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `pathAccess` hook, extend `protectedPaths` with read protection, and add session-based grants to the existing OMP hooks system.

**Architecture:** Three changes to `lib/omp.nix` (new `mkPathAccessHook`, extended `mkProtectedPathsHook`, new `mkGrantsHelper`) + corresponding Nix option declarations and wiring in `modules/home-manager/ai-tools.nix`. All hooks are OMP ExtensionAPI TypeScript extensions generated from Nix, following the exact pattern of the existing `mkPermissionGateHook` and `mkProtectedPathsHook`.

**Tech Stack:** Nix, TypeScript (generated), OMP ExtensionAPI hooks, home-manager module system

**Spec:** `docs/superpowers/specs/2026-05-20-omp-sandboxing-design.md` (Layer 2 only)

---

## File Structure

| File | Responsibility |
|------|---------------|
| `lib/omp.nix` | Hook code generators: `mkPathAccessHook`, extended `mkProtectedPathsHook`, `mkGrantsHelper`, defaults, exports |
| `modules/home-manager/ai-tools.nix` | Nix option declarations for `hooks.pathAccess.*`, `hooks.protectedPaths.protectReads`; profile-level overrides; hook wiring in `ompProfiles` and `mkOmpProfileFiles` |
| `tests/lib.nix` | Unit tests for hook code generation and grant file rendering |

---

### Task 1: Add `mkGrantsHelper` to `lib/omp.nix`

Shared grant-loading/session-grant logic used by both `pathAccess` and `permissionGate` hooks. This is a TypeScript code snippet injected into hooks that need it.

**Files:**
- Modify: `lib/omp.nix` (after `mkProtectedPathsHook`, before `hooks =`)

- [ ] **Step 1: Write the failing test**

Add to `tests/lib.nix`, inside the `runTests` attrset:

```nix
testGrantsHelperContainsLoadAndSave = {
  expr =
    let
      omp = import ../lib/omp.nix { inherit inputs lib pkgs; };
    in
    builtins.match ".*loadGrants.*saveGrant.*sessionGrants.*" omp.mkGrantsHelper != null;
  expected = true;
};
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nix eval .#checks.x86_64-linux.lib-tests --apply 'x: x' 2>&1 | head -20`
Expected: FAIL — `mkGrantsHelper` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

In `lib/omp.nix`, add `mkGrantsHelper` after `mkProtectedPathsHook` (after line 370) and before `hooks =`:

```nix
  mkGrantsHelper =
    { grantNamespace }:
    let
      grantsFile = "agent/extensions/grants.json";
    in
    ''
      var sessionGrants: Record<string, string> = {}
      var alwaysGrants: Record<string, string> = {}

      function loadGrants(): void {
        try {
          var fs = require("fs")
          var path = require("path")
          var configDir = process.env.PI_CONFIG_DIR || ".omp"
          var grantsPath = path.join(configDir, "${grantsFile}")
          if (fs.existsSync(grantsPath)) {
            var data = JSON.parse(fs.readFileSync(grantsPath, "utf8"))
            if (data && typeof data === "object") {
              alwaysGrants = data["${grantNamespace}"] || {}
            }
          }
        } catch (_) {
          // grants file missing or invalid — start empty
        }
      }

      function saveGrant(key: string, scope: string): void {
        if (scope === "always") {
          alwaysGrants[key] = "always"
          try {
            var fs = require("fs")
            var path = require("path")
            var configDir = process.env.PI_CONFIG_DIR || ".omp"
            var grantsPath = path.join(configDir, "${grantsFile}")
            var existing: Record<string, any> = {}
            if (fs.existsSync(grantsPath)) {
              existing = JSON.parse(fs.readFileSync(grantsPath, "utf8"))
            }
            existing["${grantNamespace}"] = alwaysGrants
            fs.mkdirSync(path.dirname(grantsPath), { recursive: true })
            fs.writeFileSync(grantsPath, JSON.stringify(existing, null, 2) + "\n")
          } catch (_) {
            // best effort — don't break the hook if save fails
          }
        } else if (scope === "session") {
          sessionGrants[key] = "session"
        }
      }

      function checkGrant(key: string): string | null {
        if (sessionGrants[key]) return sessionGrants[key]
        if (alwaysGrants[key]) return alwaysGrants[key]
        return null
      }

      loadGrants()
    '';
```
```

Also add `mkGrantsHelper` to the `inherit` block in the `in` section (around line 402):

```nix
  inherit
    defaultPermissionGateBlockedCommands
    defaultPermissionGateBlockedPatterns
    defaultProtectedPathGlobs
    hooks
    mkGrantsHelper
    mkPermissionGateHook
    mkProtectedPathsHook
    mkOmpConfig
    mkOmpModels
    mkOmpWrapper
    mkYamlConfig
    mkProfileHookFiles
  ;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `nix eval .#checks.x86_64-linux.lib-tests --apply 'x: x' 2>&1 | head -5`
Expected: PASS (no assertion failure)

- [ ] **Step 5: Commit**

```bash
git add lib/omp.nix tests/lib.nix
git commit -m "feat(omp): add mkGrantsHelper for session/persistent grants"
```

---

### Task 2: Add `mkPathAccessHook` to `lib/omp.nix`

New hook that blocks/prompts for tool calls targeting paths outside the workspace.

**Files:**
- Modify: `lib/omp.nix` (after `mkGrantsHelper`, before `hooks =`)

- [ ] **Step 1: Write the failing test**

Add to `tests/lib.nix`:

```nix
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nix eval .#checks.x86_64-linux.lib-tests --apply 'x: x' 2>&1 | head -20`
Expected: FAIL — `mkPathAccessHook` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

In `lib/omp.nix`, add `mkPathAccessHook` after `mkGrantsHelper`:

```nix
  defaultPathAccessAllowPaths = [
    "/nix/store"
  ];

  defaultPathAccessDenyPaths = [
    "~/.ssh"
    "~/.gnupg"
  ];

  mkPathAccessHook =
    {
      allowPaths ? defaultPathAccessAllowPaths,
      denyPaths ? defaultPathAccessDenyPaths,
      mode ? "ask",
      ...
    }:
    let
      modeAsk = mode == "ask";
    in
    ''
      ${mkGrantsHelper { grantNamespace = "pathAccess"; }}

      const ALLOW_PATHS: string[] = ${builtins.toJSON allowPaths}
      const DENY_PATHS: string[] = ${builtins.toJSON denyPaths}

      function isInsideWorkspace(fp: string): boolean {
        if (!fp) return true
        var resolved = fp
        if (fp.startsWith("~")) {
          resolved = (process.env.HOME || "") + fp.slice(1)
        }
        if (!resolved.startsWith("/")) return true
        var cwd = process.cwd()
        return resolved === cwd || resolved.startsWith(cwd + "/")
      }

      function isPathAllowed(fp: string): boolean {
        for (var i = 0; i < ALLOW_PATHS.length; i++) {
          if (fp.startsWith(ALLOW_PATHS[i])) return true
        }
        return false
      }

      function isPathDenied(fp: string): boolean {
        for (var i = 0; i < DENY_PATHS.length; i++) {
          var d = DENY_PATHS[i]
          if (d.startsWith("~")) d = (process.env.HOME || "") + d.slice(1)
          if (fp === d || fp.startsWith(d + "/")) return true
        }
        return false
      }

      const PATH_TOOLS = new Set(["read", "write", "edit", "find", "search", "filesystem_read_file", "filesystem_write_file", "filesystem_list_directory"])

      export default function (pi) {
        pi.on("tool_call", ${if modeAsk then "async function" else "function"} (call, ctx) {
          if (!PATH_TOOLS.has(call.toolName)) return

          var fp = String(call.input?.filePath ?? call.input?.path ?? call.input?.directory ?? call.input?.pattern ?? "")
          if (!fp) return

          // Expand ~ to HOME for comparison
          if (fp.startsWith("~")) fp = (process.env.HOME || "") + fp.slice(1)
          if (!fp.startsWith("/")) return // relative paths are inside workspace

          // Check deny list first — always blocks
          if (isPathDenied(fp)) {
            return { block: true, reason: "Path access denied: " + fp + " is in the deny list" }
          }

          // Check allow list — skip workspace check
          if (isPathAllowed(fp)) return

          // Check if inside workspace
          if (isInsideWorkspace(fp)) return

          // Outside workspace — check grants
          var grant = checkGrant(fp)
          if (grant) return

      ${
        if modeAsk then
          ''
            if (!ctx.hasUI) return { block: true, reason: "Path access blocked: " + fp + " is outside workspace" }
            var choice = await ctx.ui.select("Path Access", fp + " is outside the workspace. Allow access?", [
              { label: "Allow once", value: "once" },
              { label: "Allow for session", value: "session" },
              { label: "Always allow", value: "always" },
              { label: "Deny", value: "deny" }
            ])
            if (!choice || choice === "deny") return { block: true, reason: "Path access: user denied " + fp }
            if (choice === "once") return
            saveGrant(fp, choice)
          ''
        else
          ''
            return { block: true, reason: "Path access blocked: " + fp + " is outside workspace" }
          ''
      }
        })
      }
    '';
```

Also add `defaultPathAccessAllowPaths`, `defaultPathAccessDenyPaths`, and `mkPathAccessHook` to the `inherit` block in the `in` section.

- [ ] **Step 4: Run test to verify it passes**

Run: `nix eval .#checks.x86_64-linux.lib-tests --apply 'x: x' 2>&1 | head -5`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/omp.nix tests/lib.nix
git commit -m "feat(omp): add mkPathAccessHook for out-of-workspace path control"
```

---

### Task 3: Extend `mkProtectedPathsHook` with read protection

Add `protectReads` option that also blocks read operations on protected globs.

**Files:**
- Modify: `lib/omp.nix` (replace `mkProtectedPathsHook`)

- [ ] **Step 1: Write the failing test**

Add to `tests/lib.nix`:

```nix
testProtectedPathsProtectReadsIncludesReadTools = {
  expr =
    let
      omp = import ../lib/omp.nix { inherit inputs lib pkgs; };
      hook = omp.mkProtectedPathsHook { protectReads = true; };
    in
    builtins.match ".*call\\.toolName !== \"read\".*" hook == null;
  expected = true;
};

testProtectedPathsNoReadProtectionExcludesReadTools = {
  expr =
    let
      omp = import ../lib/omp.nix { inherit inputs lib pkgs; };
      hook = omp.mkProtectedPathsHook { protectReads = false; };
    in
    builtins.match ".*call\\.toolName !== \"read\".*" hook != null;
  expected = true;
};
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nix eval .#checks.x86_64-linux.lib-tests --apply 'x: x' 2>&1 | head -20`
Expected: FAIL — `protectReads` option not yet implemented.

- [ ] **Step 3: Write minimal implementation**

Replace the `mkProtectedPathsHook` function in `lib/omp.nix` (lines 336-370) with:

```nix
  mkProtectedPathsHook =
    {
      globs ? defaultProtectedPathGlobs,
      extraGlobs ? [ ],
      protectReads ? true,
      ...
    }:
    let
      allGlobs = globs ++ extraGlobs;
      readToolGuard =
        if protectReads then
          ''
            if (call.toolName !== "write" && call.toolName !== "edit" && call.toolName !== "filesystem_write_file" && call.toolName !== "read" && call.toolName !== "find" && call.toolName !== "search" && call.toolName !== "grep" && call.toolName !== "filesystem_read_file" && call.toolName !== "filesystem_list_directory") return
          ''
        else
          ''
            if (call.toolName !== "write" && call.toolName !== "edit" && call.toolName !== "filesystem_write_file") return
          '';
      reasonPrefix = if protectReads then "Protected path: accessing " else "Protected path: writing to ";
    in
    ''
      const PROTECTED_GLOBS = ${builtins.toJSON allGlobs}

      function matchesProtected(fp: string): boolean {
        for (const glob of PROTECTED_GLOBS) {
          if (glob.endsWith("/**")) {
            const prefix = glob.slice(0, -3)
            if (fp === prefix || fp.startsWith(prefix + "/")) return true
          } else {
            if (fp === glob) return true
          }
        }
        return false
      }

      export default (pi) => {
        pi.on("tool_call", (call, ctx) => {
          ${readToolGuard}

          const fp = String(call.input?.filePath ?? call.input?.path ?? call.input?.directory ?? call.input?.pattern ?? "")
          if (matchesProtected(fp)) {
            return { block: true, reason: "${reasonPrefix}" + fp + " is blocked" }
          }
        })
      }
    '';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `nix eval .#checks.x86_64-linux.lib-tests --apply 'x: x' 2>&1 | head -5`
Expected: PASS

- [ ] **Step 5: Run full test suite to check no regressions**

Run: `nix flake check --no-build 2>&1 | tail -5`
Expected: All checks pass.

- [ ] **Step 6: Commit**

```bash
git add lib/omp.nix tests/lib.nix
git commit -m "feat(omp): add protectReads option to protected paths hook"
```

---

### Task 4: Add Nix options for `pathAccess` hook to home-manager module

Declare `programs.ai-tools.tools.omp.hooks.pathAccess.*` options and wire them into the profile hook system.

**Files:**
- Modify: `modules/home-manager/ai-tools.nix`

- [ ] **Step 1: Add `pathAccess` option declarations (global level)**

In `modules/home-manager/ai-tools.nix`, inside the `hooks` attrset (after `protectedPaths` block, around line 1846), add:

```nix
          pathAccess = {
            enable =
              mkEnableOption "path access hook (controls access to paths outside the workspace)"
              // {
                default = true;
              };
            mode = mkOption {
              type = types.enum [
                "block"
                "ask"
                "allow"
              ];
              default = "ask";
              description = ''
                Response mode for the path access hook:
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
```

- [ ] **Step 2: Add `protectReads` option to `protectedPaths` (global level)**

Inside the `protectedPaths` block (around line 1846), add after `extraGlobs`:

```nix
            protectReads = mkOption {
              type = types.bool;
              default = true;
              description = ''
                When true, the protected paths hook also blocks read operations
                (read, find, search, grep) on protected paths, not just writes.
              '';
            };
```

- [ ] **Step 3: Add `pathAccess` to the default profile hooks wiring**

In the `legacyOmpProfile` definition (around line 920), inside the `hooks` block, add:

```nix
      pathAccess = {
        enable = cfg.tools.omp.hooks.pathAccess.enable;
        mode = cfg.tools.omp.hooks.pathAccess.mode;
        allowPaths = cfg.tools.omp.hooks.pathAccess.allowPaths;
        denyPaths = cfg.tools.omp.hooks.pathAccess.denyPaths;
      };
```

Also add `protectReads` to the `protectedPaths` block:

```nix
      protectedPaths = {
        enable = cfg.tools.omp.hooks.protectedPaths.enable;
        globs = cfg.tools.omp.hooks.protectedPaths.globs;
        extraGlobs = cfg.tools.omp.hooks.protectedPaths.extraGlobs;
        protectReads = cfg.tools.omp.hooks.protectedPaths.protectReads;
      };
```

- [ ] **Step 4: Add `pathAccess` hook file generation**

In `mkOmpProfileFiles` (around line 1001), in the `hookFiles` attrset, add after the `protectedPaths` block:

```nix
        // lib.optionalAttrs (profile.hooks.pathAccess.enable or false) {
          "agent/extensions/path-access.ts" = {
            text = ompSupport.mkPathAccessHook profile.hooks.pathAccess;
          };
        }
```

- [ ] **Step 5: Add per-profile `pathAccess` option declarations**

In the per-profile options section (around line 2077, inside the per-profile `hooks` block), add after `protectedPaths`:

```nix
                    pathAccess = {
                      enable = mkOption {
                        type = types.nullOr types.bool;
                        default = null;
                        description = "Per-profile path access hook override.";
                      };
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
```

Also add `protectReads` to per-profile `protectedPaths`:

```nix
                      protectReads = mkOption {
                        type = types.nullOr types.bool;
                        default = null;
                        description = "Per-profile protected paths read protection override.";
                      };
```

- [ ] **Step 6: Run `nix flake check` to verify no regressions**

Run: `nix flake check --no-build 2>&1 | tail -10`
Expected: All checks pass.

- [ ] **Step 7: Run `nix fmt` and verify no diff**

Run: `nix fmt && git diff`
Expected: No diff.

- [ ] **Step 8: Commit**

```bash
git add modules/home-manager/ai-tools.nix
git commit -m "feat(hm): add pathAccess hook and protectReads Nix options"
```

---

### Task 5: Add session grants to `permissionGate` hook

Extend `mkPermissionGateHook` in `ask` mode to support once/session/always grants for blocked patterns and commands.

**Files:**
- Modify: `lib/omp.nix` (replace `mkPermissionGateHook`)

- [ ] **Step 1: Write the failing test**

Add to `tests/lib.nix`:

```nix
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nix eval .#checks.x86_64-linux.lib-tests --apply 'x: x' 2>&1 | head -20`
Expected: FAIL — current hook does not have grant UI.

- [ ] **Step 3: Write minimal implementation**

Replace `mkPermissionGateHook` in `lib/omp.nix` (lines 271-334) with the updated version that includes `mkGrantsHelper` and grant-aware ask mode:

```nix
  mkPermissionGateHook =
    {
      blockedPatterns ? defaultPermissionGateBlockedPatterns,
      blockedCommands ? defaultPermissionGateBlockedCommands,
      extraBlockedPatterns ? [ ],
      extraBlockedCommands ? [ ],
      mode ? "ask",
      ...
    }:
    let
      allBlockedPatterns = blockedPatterns ++ extraBlockedPatterns;
      allBlockedCommands = blockedCommands ++ extraBlockedCommands;
      modeAsk = mode == "ask";
    in
    ''
      ${lib.optionalString modeAsk (mkGrantsHelper { grantNamespace = "permissionGate"; })}

      var BLOCKED_PATTERNS = [
      ${mkRegExpEntries allBlockedPatterns}
      ]

      var BLOCKED_COMMANDS = ${builtins.toJSON allBlockedCommands}

      export default function (pi) {
        pi.on("tool_call", ${if modeAsk then "async function" else "function"} (call, ctx) {
          if (call.toolName !== "bash" && call.toolName !== "shell") return

          var command = String(call.input?.command ?? "")
          if (!command) return

          for (var i = 0; i < BLOCKED_PATTERNS.length; i++) {
            if (BLOCKED_PATTERNS[i].test(command)) {
      ${
        if modeAsk then
          ''
              if (!ctx.hasUI) return { block: true, reason: "Permission gate blocked: command matches dangerous pattern" }
              var grant = checkGrant(command)
              if (grant) return
              var choice = await ctx.ui.select("Permission Gate", "Command: " + command + " may be dangerous.", [
                { label: "Allow once", value: "once" },
                { label: "Allow for session", value: "session" },
                { label: "Always allow", value: "always" },
                { label: "Deny", value: "deny" }
              ])
              if (!choice || choice === "deny") return { block: true, reason: "Permission gate: user denied command" }
              if (choice === "once") return
              saveGrant(command, choice)
          ''
        else
          ''
              return { block: true, reason: "Permission gate blocked: command matches dangerous pattern" }
          ''
      }
            }
          }

          var firstWord = command.trim().split(/\s+/)[0] ?? ""
          if (BLOCKED_COMMANDS.includes(firstWord)) {
      ${
        if modeAsk then
          ''
              if (!ctx.hasUI) return { block: true, reason: "Permission gate blocked: " + firstWord + " is not allowed" }
              var cmdGrant = checkGrant(firstWord)
              if (cmdGrant) return
              var cmdChoice = await ctx.ui.select("Permission Gate", firstWord + " is not allowed.\nCommand: " + command, [
                { label: "Allow once", value: "once" },
                { label: "Allow for session", value: "session" },
                { label: "Always allow", value: "always" },
                { label: "Deny", value: "deny" }
              ])
              if (!cmdChoice || cmdChoice === "deny") return { block: true, reason: "Permission gate: user denied command" }
              if (cmdChoice === "once") return
              saveGrant(firstWord, cmdChoice)
          ''
        else
          ''
              return { block: true, reason: "Permission gate blocked: " + firstWord + " is not allowed" }
          ''
      }
          }
        })
      }
    '';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `nix eval .#checks.x86_64-linux.lib-tests --apply 'x: x' 2>&1 | head -5`
Expected: PASS

- [ ] **Step 5: Run full flake check for regressions**

Run: `nix flake check --no-build 2>&1 | tail -10`
Expected: All checks pass.

- [ ] **Step 6: Commit**

```bash
git add lib/omp.nix tests/lib.nix
git commit -m "feat(omp): add session grants to permission gate hook"
```

---

### Task 6: Add `pathAccess` hook to the `hooks` attrset and export

Wire the new hook into the `hooks` record so it's picked up by `mkProfileHookFiles`.

**Files:**
- Modify: `lib/omp.nix`

- [ ] **Step 1: Update the `hooks` attrset**

Replace:

```nix
  hooks = {
    permissionGate = mkPermissionGateHook { };
    protectedPaths = mkProtectedPathsHook { };
  };
```

With:

```nix
  hooks = {
    permissionGate = mkPermissionGateHook { };
    protectedPaths = mkProtectedPathsHook { };
    pathAccess = mkPathAccessHook { };
  };
```

- [ ] **Step 2: Run flake check**

Run: `nix flake check --no-build 2>&1 | tail -10`
Expected: All checks pass.

- [ ] **Step 3: Commit**

```bash
git add lib/omp.nix
git commit -m "feat(omp): wire pathAccess hook into hooks attrset"
```

---

### Task 7: Integration test — verify hook files are generated in profile

**Files:**
- Modify: `tests/home-manager.nix`

- [ ] **Step 1: Add assertion that path-access.ts is generated**

In `tests/home-manager.nix`, find the existing OMP-related assertions and add a check that the `path-access.ts` extension file exists in the generated profile config directory.

Read the test file first to find the exact insertion point, then add an assertion like:

```nix
  # Verify path-access hook file is generated
  assert (builtins.pathExists "${config.home.homeDirectory}/.omp/agent/extensions/path-access.ts");
```

- [ ] **Step 2: Run flake check**

Run: `nix flake check --no-build 2>&1 | tail -10`
Expected: All checks pass.

- [ ] **Step 3: Commit**

```bash
git add tests/home-manager.nix
git commit -m "test: verify path-access hook file generation in profile"
```

---

### Task 8: Final validation — full `nix flake check` + `nix fmt`

- [ ] **Step 1: Run `nix fmt`**

Run: `nix fmt`

- [ ] **Step 2: Verify no diff after formatting**

Run: `git diff`
Expected: No diff.

- [ ] **Step 3: Run full `nix flake check`**

Run: `nix flake check 2>&1 | tail -20`
Expected: All checks pass.

- [ ] **Step 4: Final commit if formatting changed anything**

```bash
git add -A
git commit -m "style: nix fmt after hook additions" || true
```
