{
  inputs,
  pkgs,
}:

let
  system = inputs.nixpkgs.lib.nixosSystem {
    inherit (pkgs.stdenv.hostPlatform) system;
    modules = [
      inputs.home-manager.nixosModules.home-manager
      (import ../modules/nixos { inherit inputs; })
      {
        boot.loader.grub.enable = false;
        fileSystems."/".device = "test-root";
        nixpkgs.config.allowUnfree = true;
        system.stateVersion = "25.05";

        users.users.tester = {
          isNormalUser = true;
          home = "/home/tester";
        };

        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users.tester = {
          home.stateVersion = "25.05";
          programs.ai-tools = {
            enable = true;
            tools.opencode.enable = true;
            tools.opencode.profiles.work = {
              commandName = "ocw";
              configDir = ".config/opencode-work";
              mcp.memoryDir = "opencode-work";
            };
          };
        };
      }
    ];
  };

  generation = system.config.home-manager.users.tester.home.activationPackage;
in
pkgs.runCommand "ai-tools-nixos-module-tests" { nativeBuildInputs = [ pkgs.jq ]; } ''
  default_config=${generation}/home-files/.config/opencode/opencode.json
  work_config=${generation}/home-files/.config/opencode-work/opencode.jsonc
  work_wrapper=${generation}/home-path/bin/ocw

  test -f "$default_config"
  test -f "$work_config"
  test -x "$work_wrapper"

  jq -e '.theme == "catppuccin"' "$default_config" >/dev/null
  jq -e '.mcp.memory.environment.MEMORY_FILE_PATH == "/home/tester/.cache/ai-tools/default-opencode/memory.json"' "$default_config" >/dev/null
  jq -e '.mcp.memory.environment.MEMORY_FILE_PATH == "/home/tester/.cache/ai-tools/opencode-work/memory.json"' "$work_config" >/dev/null
  grep -F 'export OPENCODE_CONFIG="$HOME/.config/opencode-work/opencode.jsonc"' "$work_wrapper" >/dev/null

  touch $out
''
