## Overview

Address five high-confidence review findings in the staged AI tools changes: fix skill category filtering, place OMP assets in the documented global directory, preserve supporting files for imported external skills, honor exposed OMP options, and make OMP wrapper environment rendering shell-safe.

Files to modify:

- `modules/home-manager/ai-tools.nix` — fix skill list flattening, OMP file paths, OMP option merging, wrapper package threading, and tests-facing behavior.
- `lib/omp.nix` — update wrapper generation to accept/use the configured package and safely quote environment exports.
- `ai-tools/default.nix` and/or `ai-tools/skills*.nix` — extend skill representation if supporting files are modeled in the content layer.
- `ai-tools/skills/mattpocock/index.nix` — include `setup-matt-pocock-skills` and supporting files for Matt Pocock skills.
- `ai-tools/skills/superpowers/index.nix` — include supporting files for Superpowers skills.
- `tests/home-manager.nix` — add assertions covering category skill generation, OMP asset locations, per-profile OMP settings, memoryDir, package override if practical, and shell-safe env quoting.

## File Changes

### 1. `modules/home-manager/ai-tools.nix`

- ACTION: Update
- DESCRIPTION: Fix category skill list flattening, update OMP asset paths, honor OMP profile settings/model settings/memoryDir/package, and add any required helper plumbing for directory-style skills.

```diff
-    ++ optional cfg.skills.caveman.enable cavemanSkillNames
-    ++ optional cfg.skills.mattpocock.enable mattpocockSkillNames
-    ++ optional cfg.skills.superpowers.enable superpowersSkillNames
+    ++ optionals cfg.skills.caveman.enable cavemanSkillNames
+    ++ optionals cfg.skills.mattpocock.enable mattpocockSkillNames
+    ++ optionals cfg.skills.superpowers.enable superpowersSkillNames
```

```diff
-        lib.nameValuePair "${dir}/agents/${agentName}.md" { text = agent; }
+        lib.nameValuePair "${dir}/agent/agents/${agentName}.md" { text = agent; }

-        lib.nameValuePair "${dir}/commands/${commandName}.md" { text = command; }
+        lib.nameValuePair "${dir}/agent/commands/${commandName}.md" { text = command; }

-        lib.nameValuePair "${dir}/skills/${skillName}/SKILL.md" { text = skill; }
+        lib.nameValuePair "${dir}/agent/skills/${skillName}/SKILL.md" { text = skill; }
```

- Instructions for developer:
  1. Replace `optional` with `optionals` for repo-level skill groups.
  2. Change OMP generated agents/commands/skills paths to live under `${dir}/agent/...`.
  3. Set `legacyOmpProfile.mcp.memoryDir` from `cfg.tools.omp.mcp.memoryDir` when non-null; otherwise keep the existing `${cfg.profileName}-omp` fallback.
  4. Add a package field to normalized OMP profiles and pass it to `ompSupport.mkOmpWrapper`.
  5. Merge per-profile `settings` and `modelSettings` after global top-level settings so profile overrides actually take effect.
  6. If skill values become structured attrsets, update `filterSkills` and file generation to support both legacy string skills and directory-style skills during the transition.

- Reasoning:
  These changes make the user-facing options behave as documented and align generated OMP files with OMP's documented global discovery layout.

### 2. `lib/omp.nix`

- ACTION: Update
- DESCRIPTION: Make wrapper generation use the configured OMP package and shell-safe environment rendering.

```diff
-  mkOmpWrapper =
-    profile: runMode:
+  mkOmpWrapper =
+    profile: runMode:
     let
       commandName = if runMode then profile.runCommandName else profile.commandName;
       configDir = if profile.configDir != null then profile.configDir else ".omp";
       envVars = profile.env or { };
+      package = profile.package or llmAgents.omp;
     in
     pkgs.writeShellApplication {
       name = commandName;
-      runtimeInputs = [ llmAgents.omp ] ++ (profile.extraRuntimePackages or [ ]);
+      runtimeInputs = [ package ] ++ (profile.extraRuntimePackages or [ ]);
       text = ''
-        export PI_CONFIG_DIR="${configDir}"
+        export PI_CONFIG_DIR=${lib.escapeShellArg configDir}
       ''
       + lib.concatMapStrings (k: ''
-        export ${k}="${envVars.${k}}"
+        export ${k}=${lib.escapeShellArg envVars.${k}}
       '') (builtins.attrNames envVars)
       + ''
 
-        exec ${lib.getExe llmAgents.omp} "$@"
+        exec ${lib.getExe package} "$@"
       '';
     };
```

- Instructions for developer:
  1. Use `profile.package or llmAgents.omp` in `runtimeInputs` and `exec`.
  2. Use `lib.escapeShellArg` for `PI_CONFIG_DIR` and env values.
  3. Add validation for env var names, either via module option constraints or an assertion, so invalid names cannot generate broken shell.

- Reasoning:
  Package overrides are part of the public module API and should be respected. API keys and provider credentials must never be interpolated into shell scripts without safe quoting.

### 3. `ai-tools/skills/mattpocock/index.nix`

- ACTION: Update
- DESCRIPTION: Include the full README-selected Engineering/Productivity set and preserve supporting files.

```diff
 engineeringSkills = {
   diagnose = ...;
   grill-with-docs = ...;
   triage = ...;
   improve-codebase-architecture = ...;
+  setup-matt-pocock-skills = ...;
   tdd = ...;
   to-issues = ...;
   to-prd = ...;
   zoom-out = ...;
   prototype = ...;
 };
```

- Instructions for developer:
  1. Add `setup-matt-pocock-skills` unless intentionally excluded.
  2. Replace plain `builtins.readFile` skill values with a structure that includes `SKILL.md` plus sibling files, or create a generator that copies each source skill directory into the generated config.
  3. Keep Matt's `productivity/caveman` excluded if avoiding collision with the existing Caveman skill, but document that exclusion near the skill list.

- Reasoning:
  Imported skills reference local sibling files. Copying only `SKILL.md` breaks those references at runtime and weakens the imported workflows.

### 4. `ai-tools/skills/superpowers/index.nix`

- ACTION: Update
- DESCRIPTION: Preserve full skill directories, including supporting documentation/scripts, for all selected Superpowers skills.

- Instructions for developer:
  1. Inspect each selected Superpowers skill directory for non-`SKILL.md` files.
  2. Include those files in the generated skill output using the same structure chosen for Matt Pocock skills.
  3. Keep the public skill names stable to avoid breaking user toggles.

- Reasoning:
  Superpowers skills are designed as self-contained directories. Keeping only `SKILL.md` can leave cross-references unresolved.

### 5. `ai-tools/default.nix` / `ai-tools/skills.nix`

- ACTION: Update if needed
- DESCRIPTION: Support richer skill values while maintaining compatibility with existing string-based skills.

- Instructions for developer:
  1. Choose a canonical skill representation, for example:
     ```nix
     {
       text = builtins.readFile "${src}/.../SKILL.md";
       files = {
         "LOGIC.md".source = "${src}/.../LOGIC.md";
       };
     }
     ```
  2. Update all consumers to normalize either a string or attrset to `{ text, files }`.
  3. Preserve existing `aiTools.claudeCode.skills.<name>` string consumers until every call site is migrated, or provide a compatibility projection.

- Reasoning:
  A normalized representation prevents external skills from losing bundled resources while avoiding a large one-shot rewrite of all existing local skills.

### 6. `tests/home-manager.nix`

- ACTION: Update
- DESCRIPTION: Add regression tests for all fixed review findings.

- Instructions for developer:
  1. Assert default generated skills include a repo-category skill, e.g. `.config/opencode/skills/tdd/SKILL.md` or `.omp/agent/skills/tdd/SKILL.md`.
  2. Add a second test configuration or profile that disables `programs.ai-tools.skills.mattpocock.enable` and assert a Matt skill is absent.
  3. Assert OMP command/skill files are under `.omp/agent/...`, not `.omp/...`.
  4. Assert a supporting file exists for one external skill, e.g. `prototype/LOGIC.md` or `tdd/tests.md`.
  5. Set `tools.omp.mcp.memoryDir = "custom-omp"` and assert MCP memory path uses it.
  6. Set a profile `settings` override and `modelSettings` override and assert they appear in generated YAML.
  7. Add an env value containing shell-sensitive characters and assert the generated wrapper uses safe single-quoted shell syntax.

- Reasoning:
  The current build passed despite a runtime-visible skill filtering bug. Tests should verify generated artifacts, not only high-level config files.

## Implementation Order

1. Fix `enabledSkillNames` flattening first; this is the smallest correctness bug.
2. Fix OMP paths and OMP option honoring next; these are localized to OMP generation.
3. Update `lib/omp.nix` wrapper quoting and package use.
4. Design and apply the skill-directory representation for external skills.
5. Extend tests to cover each corrected behavior.
6. Run:
   ```bash
   nix build .#checks.x86_64-linux.home-manager-tests
   nix build .#checks.x86_64-linux.lib-tests
   nix flake check --no-build
   ```
   Treat the known NixOS `fileSystems."/".fsType` issue as pre-existing unless it changes.
