# ai-tools examples

Reference configurations for the three ways to consume this flake. Each
subfolder is a self-contained, buildable `flake.nix` you can read, copy
wholesale, or cherry-pick from.

These are **examples to learn from**, not a `nix flake init` scaffold — for a
minimal quick-start template use `nix flake init -t github:Kukkerem/ai-tools#local-dev`
(see [`../templates/local-dev`](../templates/local-dev)).

| Example | Output used | Use it when |
|---------|-------------|-------------|
| [`home-manager/`](./home-manager) | `homeManagerModules.default` | You run standalone Home Manager (`home-manager switch`) and want the tools in your real `$HOME`. |
| [`nixos/`](./nixos) | `nixosModules.default` | You manage a NixOS host and import home-manager as a NixOS module. |
| [`local-dev/`](./local-dev) | `lib.mkAiToolsDevShell` | You want a project-local AI home via `nix develop`, with no changes to your real `$HOME` or system. |

All options live under `programs.ai-tools` and are documented in the
[top-level README](../README.md).

## Before you copy

The examples are generalised so they evaluate anywhere. Adapt these before use:

- **Identity** — replace `alice` / `/home/alice` / `workstation` with your real
  username, home directory, and host name. In `nixos/`, also replace the
  placeholder bootloader and filesystem stanzas with your host's real config.
- **System** — `home-manager/` and `local-dev/` detect the arch via
  `builtins.currentSystem`; `nixos/` pins `x86_64-linux`. Change as needed.
- **Secrets** — `envFiles` / `apiKeyFile` entries point at placeholder
  `/run/secrets/...` paths. Wire them to your secret manager
  (sops-nix, agenix, …), e.g. `config.sops.secrets.openrouter-api-key.path`.
  Secret *values* are read at runtime and never enter the Nix store.
- **Models & MCP** — model IDs (`openrouter/...`) and enabled MCP servers are
  illustrative. Set the providers and servers you actually use; every MCP
  server is disabled by default.

## Trying an example against this checkout

Each example pins `ai-tools.url = "github:Kukkerem/ai-tools"`. To evaluate one
against a local checkout instead, override the input:

```bash
# Home Manager (standalone)
nix build --impure ./examples/home-manager#homeConfigurations.example.activationPackage \
  --override-input ai-tools ..

# NixOS
nix eval ./examples/nixos#nixosConfigurations.example.config.system.build.toplevel.drvPath \
  --override-input ai-tools ..

# Project-local dev shell
nix develop --impure ./examples/local-dev --override-input ai-tools ..
```

(`--impure` is only needed where the flake uses `builtins.currentSystem`.)
