{
  home-manager,
  inputs,
  lib,
}:
let
  homeDirectoryPlaceholder = "/__AI_TOOLS_DEV_HOME__";

  mkAiToolsHome =
    {
      pkgs,
      aiTools ? { },
      homeModules ? [ ],
      stateVersion ? "25.05",
      username ? "ai-tools",
    }:
    let
      aiToolsModule = import ../modules/home-manager { inherit inputs; };

      defaultAiToolsConfig = {
        enable = true;
        tools = {
          claudeCode.enable = true;
          codex.enable = true;
          opencode.enable = true;
        };
      };
    in
    home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        aiToolsModule
        {
          home = {
            inherit stateVersion username;
            homeDirectory = homeDirectoryPlaceholder;
          };

          programs.ai-tools = lib.recursiveUpdate defaultAiToolsConfig aiTools;
        }
      ]
      ++ homeModules;
    };

  mkInstallConfig =
    {
      homeConfiguration,
      pkgs,
    }:
    pkgs.writeShellApplication {
      name = "ai-tools-devshell-install-config";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnused
      ];
      text = ''
        dev_home="''${AI_TOOLS_DEV_HOME:-''${PRJ_ROOT:-$PWD}/.ai-tools/home}"

        managed_paths=(
          "$dev_home/.agents"
          "$dev_home/.claude"
          "$dev_home/.codex"
          "$dev_home/.config/opencode"
          "$dev_home/.config/rtk"
        )

        mkdir -p "$dev_home"
        chmod u+w "$dev_home" 2>/dev/null || true
        find "$dev_home" -type d -exec chmod u+w {} + 2>/dev/null || true
        for managed_path in "''${managed_paths[@]}"; do
          if [ -e "$managed_path" ]; then
            chmod -R u+w "$managed_path" 2>/dev/null || true
          fi
        done
        rm -rf "''${managed_paths[@]}"
        cp -a "${homeConfiguration.activationPackage}/home-files/." "$dev_home/"
        chmod -R u+w "$dev_home"
        for managed_path in "''${managed_paths[@]}"; do
          if [ -e "$managed_path" ]; then
            chmod -R u+w "$managed_path"
          fi
        done
        find "$dev_home" -type f -exec sed -i "s|${homeDirectoryPlaceholder}|$dev_home|g" {} +
      '';
    };

  # Shell functions that wrap each AI tool to point config/state dirs at
  # $AI_TOOLS_DEV_HOME without polluting global XDG/HOME vars for the shell.
  # These are injected into mkStartup rather than added as package wrappers to
  # avoid buildEnv collisions with the tool packages already in bundles.default.
  toolWrapperFunctions = ''
    claude() {
      local dev_home="''${AI_TOOLS_DEV_HOME:-''${PRJ_ROOT:-$PWD}/.ai-tools/home}"
      CLAUDE_CONFIG_DIR="$dev_home/.claude" command claude "$@"
    }
    opencode() {
      local dev_home="''${AI_TOOLS_DEV_HOME:-''${PRJ_ROOT:-$PWD}/.ai-tools/home}"
      OPENCODE_CONFIG_DIR="$dev_home/.config/opencode" \
      OPENCODE_CONFIG="$dev_home/.config/opencode/opencode.jsonc" \
      XDG_STATE_HOME="$dev_home/.local/state" \
      XDG_DATA_HOME="$dev_home/.local/share" \
      command opencode "$@"
    }
    codex() {
      local dev_home="''${AI_TOOLS_DEV_HOME:-''${PRJ_ROOT:-$PWD}/.ai-tools/home}"
      CODEX_HOME="$dev_home/.codex" command codex "$@"
    }
  '';

  mkStartup =
    {
      extraStartup ? "",
    }:
    ''
      export AI_TOOLS_DEV_HOME="''${AI_TOOLS_DEV_HOME:-''${PRJ_ROOT:-$PWD}/.ai-tools/home}"

      ${toolWrapperFunctions}

      ai-tools-devshell-install-config

      echo "ai-tools dev shell ready"
      echo "Project-local AI home: $AI_TOOLS_DEV_HOME"
      echo "Available CLIs: claude, codex, opencode (all scoped to AI_TOOLS_DEV_HOME)"
    ''
    + extraStartup;

  mkAiToolsDevshellConfig =
    {
      pkgs,
      aiTools ? { },
      extraCommands ? [ ],
      extraEnv ? [ ],
      extraPackages ? [ ],
      extraShellHook ? "",
      extraStartup ? "",
      homeModules ? [ ],
      name ? "ai-tools",
      stateVersion ? "25.05",
      username ? "ai-tools",
    }:
    let
      opencodeSupport = import ./opencode.nix { inherit inputs lib pkgs; };
      packageSets = import ./packages.nix { inherit inputs lib pkgs; };
      homeConfiguration = mkAiToolsHome {
        inherit
          aiTools
          homeModules
          pkgs
          stateVersion
          username
          ;
      };
      installConfig = mkInstallConfig { inherit homeConfiguration pkgs; };
      rtkPackages = [ opencodeSupport.rtkPackage ];
    in
    {
      devshell = {
        inherit name;
        packages = [
          packageSets.bundles.default
          installConfig
        ]
        ++ rtkPackages
        ++ extraPackages;
        startup.ai-tools.text = mkStartup { extraStartup = extraStartup + extraShellHook; };
        motd = ''
          {202}🔨 Welcome to ${name}{reset}
          Project-local AI configs are generated under {bold}$AI_TOOLS_DEV_HOME{reset}.
          $(type -p menu &>/dev/null && menu)
        '';
      };

      commands = [
        {
          name = "ai-tools-refresh-config";
          help = "refresh project-local Claude/Codex/OpenCode config files";
          command = "ai-tools-devshell-install-config";
        }
      ]
      ++ extraCommands;

      env = [
        {
          name = "AI_TOOLS_DEV_HOME";
          eval = "\${AI_TOOLS_DEV_HOME:-\${PRJ_ROOT:-$PWD}/.ai-tools/home}";
        }
      ]
      ++ extraEnv;
    };

  mkAiToolsDevShell =
    args@{ pkgs, ... }:
    let
      system = pkgs.stdenv.hostPlatform.system;
      devshell = inputs.devshell.legacyPackages.${system};
    in
    devshell.mkShell (mkAiToolsDevshellConfig args);
in
{
  inherit
    mkAiToolsDevShell
    mkAiToolsDevshellConfig
    ;
}
