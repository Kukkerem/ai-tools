{
  description = "Example NixOS system using ai-tools via the NixOS module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ai-tools.url = "github:Kukkerem/ai-tools";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      ai-tools,
      ...
    }:
    {
      # Build with: nixos-rebuild switch --flake .#example
      nixosConfigurations.example = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux"; # set to your host's arch

        modules = [
          # home-manager must be imported as a NixOS module so that
          # ai-tools.nixosModules.default can register the HM module into
          # every `home-manager.users.<name>` block.
          home-manager.nixosModules.home-manager
          ai-tools.nixosModules.default

          (
            { config, ... }:
            {
              nixpkgs.config.allowUnfree = true; # claude-code / codex are unfree

              # ── Minimal placeholders so the system evaluates ──────────────
              # Replace these with your real host configuration (bootloader,
              # filesystems, networking, etc.).
              boot.loader.grub = {
                enable = true;
                device = "/dev/sda";
              };
              fileSystems."/" = {
                device = "/dev/disk/by-label/nixos";
                fsType = "ext4";
              };
              networking.hostName = "workstation";
              system.stateVersion = "25.05";

              users.users.alice = {
                isNormalUser = true;
                home = "/home/alice";
              };

              # ── Home Manager glue ─────────────────────────────────────────
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;

              # `programs.ai-tools` is available here because the ai-tools NixOS
              # module added the HM module to home-manager.sharedModules. It
              # stays opt-in per user.
              home-manager.users.alice = {
                home.stateVersion = "25.05";

                programs.ai-tools = {
                  enable = true;

                  tools = {
                    claudeCode.enable = true;
                    opencode.enable = true;
                    omp.enable = true;
                  };

                  # Point nixd at this system's flake for option completion.
                  # (Only nixd uses flakePath; the `nixos` MCP server below
                  # takes no config.)
                  nixos = {
                    flakePath = "/home/alice/nix-config";
                    configurationName = config.networking.hostName;
                  };

                  mcp.servers = {
                    nixos.enable = true;
                    context7.enable = true;
                    deepwiki.enable = true;
                  };
                };
              };
            }
          )
        ];
      };
    };
}
