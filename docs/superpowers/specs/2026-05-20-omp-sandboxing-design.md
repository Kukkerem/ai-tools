# OMP Sandboxing and Guardrails Design

**Date:** 2026-05-20
**Status:** Draft

## Problem

The OMP agent has unrestricted access to the host filesystem, network, and command execution. Threats:

1. **Destructive commands** — `rm -rf`, `sudo`, disk formatting (partially covered by existing `permissionGate` hook)
2. **Credential leakage** — agent reading `.env`, SSH keys, private files
3. **Supply-chain attacks** — malicious `npm install`/`pip install` fetching compromised packages
4. **Network exfiltration** — sending data to unexpected endpoints
5. **Writes outside project folder** — modifying `.git/hooks`, shell rc files, system config

## Architecture

Two independent enforcement layers, each catching what the other misses:

```
┌─────────────────────────────────────────────┐
│  Layer 2: OMP Extension Hooks (in-process)  │
│  ┌──────────┐ ┌──────────────┐ ┌──────────┐ │
│  │pathAccess │ │protectedPaths│ │permGate  │ │
│  │(new)      │ │(extended)   │ │(existing)│ │
│  └──────────┘ └──────────────┘ └──────────┘ │
│  Intercepts tool_call events, nuance/UX      │
├─────────────────────────────────────────────┤
│  Layer 1: OS-level containment (bubblewrap)  │
│  jail.nix → bwrap namespace + mount isolation │
│  Kernel-enforced, cannot be bypassed         │
└─────────────────────────────────────────────┘
```

**Layer 1** is the safety net — kernel enforces even if hooks are bypassed.
**Layer 2** is the UX layer — intelligent feedback, session grants, per-call decisions.

## Layer 1: OS-Level Containment

### Implementation

Custom bubblewrap module built on `jail.nix` (SourceHut: `~alexdavid/jail.nix`). No `jailed-agents` dependency — write an OMP-specific `mkJailedOmpWrapper` in `lib/omp.nix`.

### New flake input

```nix
jail-nix.url = "sourcehut:~alexdavid/jail.nix";
```

### Default jail options for OMP

| Combinator | Why |
|---|---|
| `time-zone` | OMP needs timezone for timestamps |
| `no-new-session` | OMP is a TUI — `new-session` breaks keyboard input |
| `mount-cwd` | Project directory mounted read-write |
| `bind-nix-store-runtime-closure` | Only Nix store paths OMP actually needs |
| `fake-passwd` | Hide real user database from agent |
| (no `network`) | Network blocked by default — must opt in |

### OMP config paths mounted read-write

| Path | Source |
|---|---|
| `~/.omp` (or profile `configDir`) | Profile config |
| `~/.local/share/omp` (or profile `dataDir`) | Profile data |
| `~/.local/state/omp` (or profile `stateDir`) | Profile state |

### Nix options: `programs.ai-tools.tools.omp.sandbox`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable OS-level sandboxing |
| `network` | bool | false | Allow network access inside the jail |
| `extraReadwriteDirs` | listOf str | [] | Additional directories mounted read-write |
| `extraReadonlyDirs` | listOf str | [] | Additional directories mounted read-only |
| `extraPkgs` | listOf package | [] | Additional packages available inside the jail |
| `env` | attrsOf str | {} | Environment variables set inside the jail |
| `baseJailOptions` | (function → list of jail.nix Permissions) | OMP defaults | Override jail.nix combinators; each entry is a `jail-nix` combinator (e.g., `jail.combinators.network`) |

### Per-profile sandbox options

`programs.ai-tools.tools.omp.profiles.<name>.sandbox.*` — same shape as above, overrides global defaults. Each profile gets its own jailed wrapper binary (e.g., `jailed-ocw`).

### Integration with mkOmpWrapper

When `sandbox.enable = true`, wrapper generation uses `mkJailedOmpWrapper` instead of `mkOmpWrapper`. The `PI_CONFIG_DIR`, env vars, and env file vars from existing wrapper logic pass through as jail env settings. Same `commandName`/`runCommandName` pattern — users get a `jailed-omp` binary in PATH.

When `sandbox.enable = false` (default), existing `mkOmpWrapper` is used unchanged.

## Layer 2: In-Process Policy Hooks

### 2a. New `pathAccess` hook

Blocks or prompts when the agent accesses paths outside the current workspace directory.

**Behavior:**
- Intercept `read`, `write`, `edit`, `find`, `search`, `filesystem_*` tool calls
- Check if target path is inside project root (cwd)
- If outside: apply configured mode (`block`, `ask`, `allow`)
- In `ask` mode: user can grant `once`, `session`, or `always`
- Session grants stored in-memory; `always` grants persisted to `<configDir>/agent/extensions/grants.json`

**Nix options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | true | Enable path-access hook |
| `mode` | enum [block, ask, allow] | ask | Response mode for out-of-workspace access |
| `allowPaths` | listOf str | [] | Paths always allowed (e.g., /nix/store) |
| `denyPaths` | listOf str | [] | Paths always denied (e.g., ~/.ssh) |

### 2b. Extend `protectedPaths` to cover reads

Currently only intercepts write operations. Adding read interception means `.env`, `.ssh/**`, and other sensitive files cannot be read by the agent.

**New option:** `protectReads` (bool, default true) — when true, also blocks `read`, `find`, `search`, `grep` on protected globs.

### 2c. Session-based grants

Both `permissionGate` (in `ask` mode) and `pathAccess` support session grants:

- `allow once` — grants for this single tool call only
- `allow for session` — grants until OMP exits (in-memory Map)
- `always allow` — writes grant to `grants.json`, loaded on startup

Grants file format:

```json
{
  "pathAccess": {
    "/nix/store": "always",
    "/etc/ssl": "always"
  },
  "permissionGate": {
    "git push": "always"
  }
}
```

`session` grants are never written to disk — they exist only in the in-memory Map and are cleared on OMP exit. `always` grants are persisted to `grants.json`. File is human-editable for cleanup.

## Implementation Phasing

The two layers are independent and will be implemented separately:

**Phase 1 — Layer 2: In-Process Policy Hooks.** New `pathAccess` hook, extended `protectedPaths` read protection, session-based grants. No new flake inputs. Modifies `lib/omp.nix` and `modules/home-manager/ai-tools.nix` only.

**Phase 2 — Layer 1: OS-Level Containment.** Custom bubblewrap module via `jail-nix`, `mkJailedOmpWrapper`, sandbox Nix options. Requires new `jail-nix` flake input. Modifies `flake.nix`, `lib/omp.nix`, `modules/home-manager/ai-tools.nix`.

Phase 1 is implemented first because it provides immediate security value without any new dependencies, and can be tested in isolation.

## Data Flow: Sandboxed OMP Launch

1. User runs `jailed-omp` (or `jailed-ocw` for a profile)
2. Shell wrapper sets `PI_CONFIG_DIR`, env vars, env file vars
3. Instead of direct `exec omp`, wrapper execs the jail.nix-generated bubblewrap entrypoint
4. bubblewrap sets up namespace, mounts, and network isolation
5. Inside jail, OMP starts with only mounted paths and allowed binaries visible
6. OMP loads extensions — hooks register on `tool_call` event
7. Agent issues tool call:
   - Hook layer intercepts: `pathAccess` → `protectedPaths` → `permissionGate`
   - Hook blocks → agent gets reason string, no kernel enforcement needed
   - Hook allows → tool executes inside jail, kernel enforces boundaries

## Error Handling

| Layer | Failure mode | Behavior |
|-------|-------------|----------|
| Jail fails to start | Missing mount path, bwrap error | Wrapper exits with error, user sees bwrap stderr |
| Path not mounted in jail | Agent tries to read `~/.ssh/id_rsa` | Kernel returns EACCES/ENOENT — agent sees "file not found" |
| Network blocked, agent tries fetch | Agent runs `curl` | `curl` fails with network unreachable |
| Hook blocks a tool call | Agent tries `rm -rf /` | `permissionGate` returns `{ block: true, reason }` — agent gets reason |
| Hook crashes | Extension throws during `tool_call` | OMP fails closed — tool call is blocked |

## Testing

| Test type | What it covers | How |
|-----------|---------------|-----|
| Nix unit tests | `mkJailedOmpWrapper` generates correct bwrap flags | `tests/lib.nix` — assert wrapper contains `--unshare-net`, `--bind` flags |
| Nix unit tests | Hook code generation (pathAccess, readProtection) | `tests/lib.nix` — assert generated TS contains correct patterns |
| NixOS VM test | Sandboxed OMP can read project dir but not `~/.ssh` | `tests/nixos.nix` — attempt read outside workspace, verify EACCES |
| NixOS VM test | Network isolation with `network = false` | `tests/nixos.nix` — verify `curl` fails |
| Existing tests | No regressions with `sandbox.enable = false` | CI — all existing `home-manager-tests` and `nixos-module-tests` pass |

## Out of Scope

- Network domain allowlisting (requires fence or a proxy — can be added later as Layer 3)
- Per-command network policy at the kernel level (same as above)
- macOS support (bubblewrap is Linux-only; macOS users rely on hooks only)
- GUI/desktop integration (OMP is TUI-only, no D-Bus/Wayland/pulseaudio needed)
- Interactive settings UI or onboarding wizard (configure via Nix, not at runtime)
