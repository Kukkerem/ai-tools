

# Bubblewrap Sandboxing for AI Coding Agents

Research, findings, comparative analysis, and implementation plan for adding bubblewrap-based sandboxing to the `ai-tools` Home Manager module.

**Date**: 2026-05-11
**Status**: Research complete — ready for Phase 1 implementation

---

## Motivation

I want to bubblewrap my opencode agent (and possibly claude code and codex) so that AI coding agents operate inside an OS-enforced sandbox rather than having unrestricted access to my machine. The reference implementation is [`michalrus/opencode-bwrap-nix`](https://github.com/michalrus/opencode-bwrap-nix), which wraps OpenCode inside a Bubblewrap sandbox on Linux with a declarative Nix/Home Manager module.

---

## Landscape Analysis: The Ecosystem at a Glance

The AI coding agent ecosystem is rapidly adopting `bubblewrap` (bwrap) as the Linux sandboxing primitive. As of May 2026:

| Tool | Sandboxing Status | Mechanism |
|------|------------------|-----------|
| **Codex (OpenAI)** | Native, enabled by default | Landlock + seccomp; bwrap support merged (PR #9938) |
| **Claude Code (Anthropic)** | Opt-in via runtime flag | Seatbelt (macOS) / bubblewrap (Linux) via `@anthropic-ai/sandbox-runtime` |
| **OpenCode** | None (no native sandboxing) | Gap filled by community wrappers |
| **Gemini CLI** | Opt-in, disabled by default | OS-level sandbox |
| **Goose, Droid, others** | None | No meaningful OS isolation |

Six+ distinct Nix-based sandboxing projects exist, indicating strong community demand.

---

## Comparative Analysis of Existing Projects

### 1. `michalrus/opencode-bwrap-nix` (★ Reference Implementation)

**Stack**: Nix flake + Home Manager module + Rust escape hatch
**Complexity**: High
**Agent support**: OpenCode only

```
Layout:
├── flake.nix (66 lines)        # Entry: nixpkgs 25.11 + pinned opencode + bun2nix + serena
├── hm-module.nix (357 lines)   # HM module: options, systemd units, config generation
├── opencode-bwrap/              # Main sandbox wrapper package (Nix + shell + seccomp)
├── bwrap-escape-hatch/          # Escape-hatch service (Rust, ~180 lines)
│   ├── src/main.rs              # Socket-activated, fnmatch allow-list matching
│   └── README.md                # Wire protocol documentation
├── plugins/                     # opencode plugins (anthropic-auth, notifier)
└── preamble/                    # Instructions file mounted into sandbox
```

**Key Architecture — Three Layers**:

1. **HM Module** (`hm-module.nix`): Declarative options for `enable`, `dataDirPrefix`, `extraPackages`, `extraEnv`, `extraFwdEnv`, `treefmt`, `serena`, `notifications` (per-event sounds + messages), `compaction`, `provider`. Generates escape-hatch rules, notifier config, and converts sounds to WAV at build time.

2. **Sandbox Wrapper** (`opencode-bwrap/`): Shell script that invokes bwrap with `--unshare-all`, seccomp-BPF filter, declarative bind mounts, custom zshrc/bashrc, PATH construction, and MCP server config. Drops into sandboxed zsh shell.

3. **Escape Hatch** (`bwrap-escape-hatch/`): Systemd socket-activated Rust service (one handler per connection). Wire protocol: client sends JSON argv array, service matches against fnmatch(3) allow-list, runs command (or rejects), returns `{ ok, exit_code }`. Rejects arguments containing `..` (path traversal prevention).

**Security Model (Defense in Depth)**:

| Layer | Mechanism | What It Prevents |
|-------|-----------|-----------------|
| Namespace isolation | `--unshare-all` (PID, net, mount, IPC, UTS, cgroup) | Process/network/filesystem visibility |
| Filesystem restrictions | Read-only .git, tmpfs /tmp | History rewriting, persistent tampering |
| Terminal protection | Seccomp-BPF filter blocking `TIOCSTI` ioctl | CVE-2017-5226 keystroke injection (CVSS 10.0) |
| Environment isolation | Clean environment, explicit forwarding | Config/secret leakage |
| Controlled escapes | Socket-activated allow-list-gated service | Arbitrary sandbox breakout |
| Privilege separation | `PR_SET_NO_NEW_PRIVS` (built into bwrap) | SUID binary exploits |
| Path traversal | Reject arguments with `..` | Directory traversal attacks |

**Elegant Nix Patterns** (worth adopting):

```nix
# Build-time sound conversion (no runtime ffmpeg needed)
toWav = name: src:
  pkgs.runCommand "opencode-sound-${name}.wav" {
    nativeBuildInputs = [ pkgs.ffmpeg-headless ];
  } ''
    ffmpeg -y -i ${lib.escapeShellArg "${src}"} -ar 44100 -ac 2 "$out"
  '';

# Module validation without requiring real home-manager
hmOptionStubs = {
  options = {
    home.packages = lib.mkOption { type = lib.types.listOf lib.types.package; default = []; };
    systemd.user = lib.mkOption { type = lib.types.anything; default = {}; };
    assertions = lib.mkOption { type = lib.types.listOf lib.types.anything; default = []; };
  };
};

# Build-time allow-list generation from Nix data
notifRules = [
  { note = "basic notification";
    argv = ["${pkgs.libnotify}/bin/notify-send" "--" "*" "*"]; }
  { note = "notification sounds";
    argv = ["${pkgs.alsa-utils}/bin/aplay" "${soundsDir}/*.wav"]; }
];

# Compile-time assertion validation
assertions = [
  { assertion = lib.all (name: builtins.match "[a-zA-Z_][a-zA-Z_0-9]*" name != null)
      (builtins.attrNames cfg.extraEnv);
    message = "extraEnv: every key must be a valid POSIX variable name"; }
  { assertion = lib.all (segment: segment != "" && segment != "." && segment != "..")
      (lib.splitString "/" cfg.dataDirPrefix);
    message = "dataDirPrefix: must be a normalized relative path under $HOME"; }
];
```

---

### 2. `debrandt/jailed-agents` (MIT)

**Stack**: jail.nix combinators + Nix flake lib functions
**Complexity**: Medium
**Agent support**: Claude Code, Codex, OpenCode, Crush, Pi, Gemini CLI

```
Layout:
├── claude-code/   # Pre-configured jailed claude-code builder
├── crush/         # Pre-configured jailed crush builder
├── opencode/      # Pre-configured jailed opencode builder
├── pi/            # Pre-configured jailed pi builder
├── gemini-cli/    # Pre-configured jailed gemini-cli builder
├── combinators/   # Reusable jail.nix combinators
└── flake.nix
```

**Key characteristics**:
- Zero-trust by default: no access to home directory, SSH keys, or sensitive files
- `jailed-` prefix convention makes sandboxing visible: `jailed-opencode`, `jailed-claude-code`
- 14 common packages included by default (bash, curl, git, ripgrep, jq, etc.)
- Builder API: `makeJailedOpencode { extraPkgs, extraReadwriteDirs, extraReadonlyDirs, ... }`
- Built on `jail.nix` (by Alex David) — a declarative Nix library for bwrap sandboxes
- Lower complexity than opencode-bwrap-nix — no escape hatch, no notifications

```nix
# Usage example
jailed-agents.lib.${system}.makeJailedOpencode {
  extraPkgs = [ pkgs.nodejs pkgs.python3 ];
  extraReadwriteDirs = [ "~/projects" ];
  extraReadonlyDirs = [ "~/readonly-cache" ];
}
```

---

### 3. `bindsch/scode` (MIT, v0.2.0)

**Stack**: Single bash script (~3500 lines)
**Complexity**: Low
**Agent support**: Agent-agnostic (opencode, claude, codex, goose, gemini, droid, qwen, codemux, pi)

**Key characteristics**:
- One policy, all agents — config once, apply uniformly across tools
- macOS: `sandbox-exec` (Seatbelt profiles), Linux: `bubblewrap`
- Trust presets: `trusted` (minimal), `standard`, `untrusted` (maximum = strict + no-net + scrub + ro)
- YAML config: `~/.config/scode/sandbox.yaml` + per-project `.scode.yaml`
- `audit` subcommand: parses denial logs, suggests `--allow` flags
- Auto-detects harnesses and transparent wrappers (env, nice, timeout, stdbuf, etc.)
- Browser support: auto-disables nested sandboxing (Electron, Playwright, Chromium)
- Extremely lightweight — no Nix integration, no daemon, no language runtime

**Default blocked paths**:
```
~/Documents, ~/Desktop, ~/Pictures, ~/Downloads
~/.aws, ~/.azure, ~/.config/gcloud, ~/.kube, ~/.docker
~/.gnupg, ~/.1password, ~/.op, ~/.password-store
~/.npmrc, ~/.netrc, ~/.git-credentials, ~/.pypirc
~/.gem/credentials, ~/.cargo/credentials.toml
~/.config/gh, ~/.config/hub
~/Library (macOS only — with browser/keychain carve-outs)
Additional Linux-specific: browser profiles, keyrings, email clients, Flatpak/Snap data
```

---

### 4. `clinta/opencode-sandbox-plugin`

**Stack**: OpenCode plugin (TypeScript, npm)
**Complexity**: Low
**Agent support**: OpenCode only

- Uses `@anthropic-ai/sandbox-runtime` engine
- Intercepts `tool.execute.before` / `tool.execute.after` hooks
- Filesystem: allow-write only to project dir + /tmp, deny-read sensitive paths
- Network: domain allow-list via local proxy
- **Fail-open design** — sandbox failures never break the agent's workflow
- Config stored outside project dir (in `~/.config/opencode-sandbox/`) — prevents indirect prompt injection
- Not Nix-native — requires npm/node runtime

---

### 5. `tomeon/bubbLLMwrap`

**Stack**: Nix flake lib functions
**Complexity**: Medium
**Agent support**: Claude Code primarily

**Profile-based architecture** with 9 built-in language profiles:

| Profile | Command | Tools Included |
|---------|---------|---------------|
| Base | `claude-sandbox` | Core utils, git, jujutsu, vim |
| Bare | `claude-sandbox-bare` | bash, coreutils only |
| Nix | `claude-sandbox-nix` | nix, alejandra |
| Go | `claude-sandbox-go` | go, gopls, delve, golangci-lint |
| Python | `claude-sandbox-python` | python3, pip, poetry, ruff, pyright, uv |
| Rust | `claude-sandbox-rust` | rustc, cargo, rust-analyzer, clippy |
| C++ | `claude-sandbox-cpp` | gcc, clang, cmake, make, clang-tools |
| JavaScript | `claude-sandbox-js` | nodejs, yarn, pnpm, bun, typescript |
| DevOps | `claude-sandbox-devops` | docker, kubectl, terraform, helm, awscli2 |

- HTTP proxy with domain allow-list filtering
- Language-specific cache bindings (e.g., `~/.cargo/registry` for Rust)
- `mkSandbox` builder: `{ name, packages, env, preStartHooks, args, allowList, customPrompt }`

---

### 6. `vossiman/bw-AICode`

**Stack**: Shell scripts + Go Docker guard proxy
**Complexity**: Medium
**Agent support**: Claude Code, OpenCode

- `claude-bw.sh` / `opencode-bw.sh` shell wrappers
- `bw-docker-guard` Go proxy for Docker access control
- Sensitive file deny hooks for Claude Code `PreToolUse`
- Read-only project mode via `OPENCODE_PERMISSION` rules
- Docker mode detection: Read-only (no compose), Guarded (compose present), Unrestricted (`--full-docker`)

---

## Security Deep Dive

### CVE-2017-5226 — TIOCSTI Terminal Injection

**CVSS Score**: 10.0 (Critical)
**Issue**: A sandboxed process can inject keystrokes into the parent terminal's input buffer using the `TIOCSTI` ioctl, effectively escaping the sandbox.

**Mitigations**:
- `--new-session` (calls `setsid()`) — breaks job control in interactive shells
- **Seccomp-BPF filter blocking `TIOCSTI`** — the approach used by opencode-bwrap-nix, recommended by bubblewrap maintainers

### Other Attack Vectors to Consider

| Vector | Impact | Mitigation |
|--------|--------|-----------|
| D-Bus socket exposure | Command execution via systemd | Don't bind D-Bus socket into sandbox |
| X11/Wayland socket | Keylogging, screen capture | Isolate or don't bind |
| `/proc` and `/sys` exposure | Host information leakage | Mount selectively or use tmpfs |
| Inherited PTY file descriptors | Terminal escape | seccomp filter + `--unshare-all` |
| SUID binaries | Privilege escalation | `PR_SET_NO_NEW_PRIVS` (built into bwrap) |
| Browser profiles in sandbox | Cookie/session theft | Block browser profile directories by default |

---

## Current State of `ai-tools` Project

The project already has a solid foundation:

```
flake.nix                           # Multi-system flake (x86_64-linux, aarch64-linux, darwin)
├── inputs: nixpkgs, home-manager, devshell, llm-agents, mcp-servers-nix, mcp-nixos, caveman
├── homeManagerModules.default      # Imported from modules/home-manager/
├── nixosModules.default            # Imported from modules/nixos/
├── packages: default, mcp, claude-code, codex, opencode
├── devShells.default               # Full dev environment
├── checks.default                  # HM activation build validation
└── formatter                       # nixfmt-based

modules/home-manager/ai-tools.nix   # 1263 lines — the core module
├── options.programs.ai-tools       # Rich option tree
│   ├── enable, profileName, nixos (flakePath, configurationName)
│   ├── tools.claudeCode            # enable, settings, model, program pass-through
│   ├── tools.codex                 # enable, settings, model, reasoningEffort, sandboxMode, approvalPolicy
│   ├── tools.opencode              # enable, settings, theme, model, plugins, lsp, dcp, rtk, profiles[].mcp
│   └── mcp                         # 18 MCP server options with per-profile overrides
└── config                          # Generation: settings, config files, wrappers, home packages

lib/packages.nix                    # Package set definitions
├── sharedAgentPackages             # agent-browser, claude-plugins, coreutils, jq
├── serenaSupportPackages           # gopls, nixd
├── opencodeRuntimePackages         # Language servers, formatters
├── mcpRuntimePackages              # All MCP server binaries + browser
└── bundles                         # default, mcp (buildEnv combinations)
```

**What already exists for sandboxing**:
- Codex sandbox settings modeled: `sandboxMode` (`read-only` / `workspace-write` / `danger-full-access`), `approvalPolicy` (`never` / `on-failure` / `untrusted` / `on-request`)
- No bubblewrap/sandbox integration exists yet — this is greenfield

---

## Implementation Plan for `ai-tools`

### Design Philosophy

- **Nix-native**: Everything declarative, build-time validated, no runtime dependencies beyond `bubblewrap`
- **Multi-tool**: One sandbox concern, applied uniformly across OpenCode, Claude Code, Codex
- **Progressive**: Start simple (Phase 1), add configurability (Phase 2), then advanced features (Phase 3)
- **Fail-safe**: If bwrap is unavailable, agent still runs (just without sandbox)
- **Composable**: Works with existing profile system, doesn't require refactoring

### Option Analysis

Three integration approaches were evaluated:

**A) Shared Sandboxing Concern** (Recommended)
- New `programs.ai-tools.sandboxing` namespace (under `options.programs.ai-tools`)
- Unified sandbox config that each tool inherits
- Minimal changes to existing code — conditional bwrap prefix embedded inside `mkOpencodeWrapper` and `programs.claude-code.package` rather than replacing them
- Supports tool-specific overrides

**B) Per-Profile Sandbox Config**
- Embed sandbox config inside each OpenCode profile
- Tighter coupling to profile system
- More config duplication across tools

**C) Adopt `opencode-bwrap-nix` as Flake Input**
- Quickest path but adds external dependency
- Separate option namespace (`programs.opencode-bwrap` vs `programs.ai-tools`)
- Nixpkgs version conflicts (they pin 25.11)

**Decision**: Option A — shared sandboxing concern

### Phased Implementation

#### Phase 1: Basic Sandbox Wrapper (MVP)

**Scope**: ~80 lines of Nix (revised from 50 after backward-compat analysis)
**Goal**: Prove the approach with minimal complexity while preserving full backward compatibility

**Key constraint**: The bwrap layer must be integrated INTO existing wrappers, not replace them. This is necessary because:
- `mkOpencodeWrapper` sets critical profile-specific env vars (`OPENCODE_CONFIG`, `OPENCODE_CONFIG_DIR`, `XDG_DATA_HOME`, `XDG_STATE_HOME`) that must survive into the sandbox via `--setenv`
- `extraRuntimePackages` must remain in PATH inside the sandbox
- Multiple OpenCode profiles (each with their own config dir) need per-profile bwrap with correct bind-mounts
- Existing tool names (`opencode`, `claude`, `codex`) must remain unchanged

**Approach: Conditional bwrap prefix embedded in existing wrappers**

```nix
# In ai-tools.nix — modified mkOpencodeWrapper (lines 346-367 expanded):
mkOpencodeWrapper = profile: runMode:
  pkgs.writeShellApplication {
    name = profile.commandName;
    runtimeInputs = [ llmAgents.opencode ]
      ++ optional cfg.sandboxing.enable pkgs.bubblewrap   # NEW
      ++ profile.extraRuntimePackages;
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
    # NEW: conditional bwrap prefix with --setenv for all profile vars
    + optionalString cfg.sandboxing.enable ''
      exec bwrap \
        --unshare-all \
        --share-net \
        --ro-bind /nix /nix \
        --ro-bind "$HOME/.gitconfig" "$HOME/.gitconfig" \
        --bind "$PWD" "$PWD" \
        --bind "$HOME/${profile.configDir}" "$HOME/${profile.configDir}" \
        --setenv OPENCODE_CONFIG "$OPENCODE_CONFIG" \
        --setenv OPENCODE_CONFIG_DIR "$OPENCODE_CONFIG_DIR" \
        ${optionalString (profile.dataDir != null) "--setenv XDG_DATA_HOME \"$XDG_DATA_HOME\""} \
        ${optionalString (profile.stateDir != null) "--setenv XDG_STATE_HOME \"$XDG_STATE_HOME\""} \
        --tmpfs /tmp \
        --proc /proc \
        --dev /dev \
        --die-with-parent \
        --chdir "$PWD" \
        --seccomp 9 \
        9< ${./seccomp-tiocsti.bpf} \
        ${lib.getExe llmAgents.opencode} ${optionalString runMode "run "}"$@"
    ''
    + optionalString (!cfg.sandboxing.enable) ''
      exec ${lib.getExe llmAgents.opencode} ${optionalString runMode "run "}"$@"
    '';
  };
```

Claude Code follows the same pattern:
```nix
# Conditional bwrap-wrapped claude binary — all existing config unchanged
programs.claude-code.package = mkIf cfg.sandboxing.enable
  (pkgs.writeShellApplication {
    name = "claude";
    runtimeInputs = [ pkgs.bubblewrap llmAgents.claude-code ];
    text = ''
      exec bwrap \
        --unshare-all --share-net \
        --ro-bind /nix /nix \
        --ro-bind "$HOME/.gitconfig" "$HOME/.gitconfig" \
        --bind "$PWD" "$PWD" \
        --bind "$HOME/.claude" "$HOME/.claude" \
        --tmpfs /tmp --proc /proc --dev /dev \
        --die-with-parent --chdir "$PWD" \
        --seccomp 9 9< ${./seccomp-tiocsti.bpf} \
        ${lib.getExe llmAgents.claude-code} "$@"
    '';
  });
```

**Deliverables**:
- `lib/sandbox.nix` — shared sandbox utilities (seccomp filter generation, mount-arg builders)
- `ai-tools/seccomp-tiocsti.bpf` — pre-compiled seccomp filter
- Updated `ai-tools.nix` — `sandboxing.enable` option + conditional bwrap integration in both `mkOpencodeWrapper` and claude code `package`
- README update documenting the feature

**Backward compatibility guarantees**:
- `cfg.sandboxing.enable` defaults to `false` — all existing behavior preserved
- When enabled: all profile env vars, `extraRuntimePackages`, and tool names remain identical
- When disabled: wrapper scripts compile down to the exact same output as today
- Codex is explicitly excluded from bwrap wrapping (it has its own native sandbox)

#### Phase 2: Configurable Sandbox

**Scope**: ~150 additional lines of Nix
**Goal**: Full declarative control over sandbox boundaries

```nix
programs.ai-tools.sandboxing = {
  enable = true;
  
  # Security mode
  mode = mkOption {
    type = types.enum [ "strict" "standard" "permissive" ];
    default = "standard";
    description = ''
      - strict: deny-default — only explicitly allowed paths are accessible
      - standard: allow-default with sensible deny rules (default)
      - permissive: allow-default, only deny explicit blocked paths
    '';
  };
  
  # Filesystem controls
  filesystem = {
    writableDirs = mkOption {
      type = types.listOf types.str;
      default = [ ];  # Project dir is always writable
      example = [ "~/projects" "~/nix-config" ];
    };
    readonlyDirs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "/nix" "/etc" ];
    };
    blockedDirs = mkOption {
      type = types.listOf types.str;
      default = [
        "~/.ssh" "~/.gnupg" "~/.aws"
        "~/.config/gcloud" "~/.kube"
        "~/.npmrc" "~/.netrc"
      ];
    };
  };
  
  # Network controls
  network = {
    enable = mkOption { type = types.bool; default = true; };
    allowedDomains = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "When non-empty, restricts outbound connections via proxy allow-list";
    };
  };
  
  # Per-tool overrides
  tools = {
    opencode = {
      enable = mkOption { type = types.bool; default = true; };
      readOnlyGit = mkOption { type = types.bool; default = true; };
      extraWritableDirs = mkOption { type = types.listOf types.str; default = []; };
    };
    claudeCode = {
      enable = mkOption { type = types.bool; default = true; };
      readOnlyGit = mkOption { type = types.bool; default = true; };
    };
    codex = {
      enable = mkOption { type = types.bool; default = false; };  # Codex has its own
      inheritCodexSandbox = mkOption { type = types.bool; default = true; };
    };
  };
  
  # Security hardening
  security = {
    blockTIOCSTI = mkOption { type = types.bool; default = true; };
    readOnlyGit = mkOption { type = types.bool; default = true; };
    noNewPrivileges = mkOption { type = types.bool; default = true; };
  };
};
```

**Deliverables**:
- Full option tree with validation
- Per-tool sandbox configuration
- Integration with existing `extraPackages` / `extraEnv` / `extraFwdEnv` patterns
- Test coverage

#### Phase 3: Advanced Features

**Scope**: ~200 additional lines + optional Rust binary
**Goal**: Production-grade sandbox with controlled escapes

- **Escape Hatch**: Systemd socket-activated service for notifications, sounds, and approved host operations
- **Audit Mode**: Log sandbox denials and provide `--allow` suggestions (inspired by scode)
- **Network Proxy**: HTTP proxy with domain allow-list (like bubbLLMwrap)
- **Docker Guard**: Controlled Docker access via proxy (like bw-AICode)
- **Build-time Validation**: Full `lib.evalModules` checks like opencode-bwrap-nix

---

## Key Ideas to Adopt

From analyzing all six projects, these patterns stand out for direct adoption:

| Pattern | Source | Why |
|---------|--------|-----|
| Read-only `.git` mount | opencode-bwrap-nix | Simple, high-value security |
| TIOCSTI seccomp filter | opencode-bwrap-nix | Essential (CVE 10.0), recommended by bwrap docs |
| fnmatch allow-list pattern matching | opencode-bwrap-nix | Flexible, well-understood semantics |
| `jailed-` prefix convention | jailed-agents | Makes sandboxing visible to users |
| Audit subcommand (denial log parsing) | scode | Helps users discover needed `--allow` flags |
| Config outside sandbox | opencode-sandbox-plugin | Prevents indirect prompt injection |
| Fail-open design | opencode-sandbox-plugin | Sandbox failures don't break the agent |
| Systemd socket activation | opencode-bwrap-nix | Zero overhead when idle, elegant architecture |
| Build-time asset generation | opencode-bwrap-nix | No runtime ffmpeg needed for sounds |
| Module assertions | opencode-bwrap-nix | Compile-time input validation |
| Multi-profile language support | bubbLLMwrap | Language-specific toolchains and caches |

---

## Decision Log

- **2026-05-11**: Chose Option A (shared sandboxing concern) over B (per-profile) and C (adopt external flake)
  - Rationale: Cleanest integration with existing architecture, minimal coupling, no external dependency
- **2026-05-11**: Phase 1 scope defined as basic bwrap wrapper with TIOCSTI filter integrated into existing wrappers
  - Rationale: ~80 lines of Nix (revised from 50 after backward-compat analysis), immediate security value, validates the approach before adding complexity
- **2026-05-11**: Codex sandbox will not be managed by our bwrap wrapper since it has its own native implementation
  - Rationale: Avoid double-sandboxing; we already model `sandboxMode`/`approvalPolicy` for Codex
- **2026-05-11**: Bwrap layer embedded inside existing wrappers (not standalone replacement)
  - Rationale: Backward compatibility audit revealed that OpenCode wrapper sets critical profile-specific env vars (`OPENCODE_CONFIG`, `XDG_DATA_HOME`, etc.) which bwrap discards with `--unshare-all`. These must be explicitly forwarded via `--setenv`. Also, `extraRuntimePackages`, per-profile config dirs, and tool names must survive unchanged.
- **2026-05-11**: `sandboxing.enable` defaults to `false` for zero-risk rollout
  - Rationale: When disabled, wrapper scripts compile to identical output as today — full opt-in, no surprises

---

## References

- [michalrus/opencode-bwrap-nix](https://github.com/michalrus/opencode-bwrap-nix) — Reference implementation
- [debrandt/jailed-agents](https://github.com/debrandt/jailed-agents) — jail.nix-based sandbox
- [bindsch/scode](https://github.com/bindsch/scode) — Agent-agnostic bash wrapper
- [clinta/opencode-sandbox-plugin](https://github.com/clinta/opencode-sandbox-plugin) — OpenCode plugin approach
- [tomeon/bubbLLMwrap](https://github.com/tomeon/bubbLLMwrap) — Profile-based sandbox
- [vossiman/bw-AICode](https://github.com/vossiman/bw-AICode) — Shell scripts + Docker guard
- [Codex Sandboxing Docs](https://developers.openai.com/codex/concepts/sandboxing)
- [Bubblewrap README](https://github.com/containers/bubblewrap) — Security model and limitations
- [CVE-2017-5226](https://ubuntu.com/security/CVE-2017-5226) — TIOCSTI terminal injection
- [bubblewrap PR #143](https://github.com/projectatomic/bubblewrap/pull/143) — setsid() fix discussion
- [NixOS Discourse: Claude Code and security isolation](https://discourse.nixos.org/t/claude-code-and-security-isolation/71543)

---

---

## Related Project Memory

See also:
- `nix-conventions.md` — Nix code style conventions for the project
- `ai-tools-enterprise-2026-03-31.md` — Enterprise AI tools configuration overview
- `opencode-mem on NixOS.md` — Related OpenCode memory integration work
