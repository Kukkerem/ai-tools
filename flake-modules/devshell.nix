{
  devShellSupport,
  inputs,
}:
{
  flake-parts-lib,
  lib,
  ...
}:
let
  inherit (flake-parts-lib) mkPerSystemOption;
in
{
  imports = [ inputs.devshell.flakeModule ];

  options.perSystem = mkPerSystemOption (
    { config, pkgs, ... }:
    {
      options.ai-tools.devshells = lib.mkOption {
        type = lib.types.lazyAttrsOf (
          lib.types.submodule (
            { name, ... }:
            {
              options = {
                aiTools = lib.mkOption {
                  type = lib.types.attrsOf lib.types.anything;
                  default = { };
                  description = "Configuration merged into programs.ai-tools for this devshell.";
                };

                extraCommands = lib.mkOption {
                  type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
                  default = [ ];
                  description = "Additional numtide/devshell commands.";
                };

                extraEnv = lib.mkOption {
                  type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
                  default = [ ];
                  description = "Additional numtide/devshell environment entries.";
                };

                extraPackages = lib.mkOption {
                  type = lib.types.listOf lib.types.package;
                  default = [ ];
                  description = "Additional packages to include in the devshell.";
                };

                extraShellHook = lib.mkOption {
                  type = lib.types.lines;
                  default = "";
                  description = "Compatibility alias for additional startup shell code.";
                };

                extraStartup = lib.mkOption {
                  type = lib.types.lines;
                  default = "";
                  description = "Additional startup shell code for the devshell.";
                };

                homeModules = lib.mkOption {
                  type = lib.types.listOf lib.types.deferredModule;
                  default = [ ];
                  description = "Additional Home Manager modules used while generating project-local AI config files.";
                };

                name = lib.mkOption {
                  type = lib.types.str;
                  default = name;
                  description = "Name of the generated devshell.";
                };

                stateVersion = lib.mkOption {
                  type = lib.types.str;
                  default = "25.05";
                  description = "Home Manager state version used for generated project-local AI config files.";
                };

                username = lib.mkOption {
                  type = lib.types.str;
                  default = "ai-tools";
                  description = "Home Manager username used for generated project-local AI config files.";
                };
              };
            }
          )
        );
        default = { };
        description = "AI tools devshells backed by numtide/devshell.";
      };

      config.devshells = lib.mapAttrs (
        _shellName: cfg:
        devShellSupport.mkAiToolsDevshellConfig {
          inherit pkgs;
          inherit (cfg)
            aiTools
            extraCommands
            extraEnv
            extraPackages
            extraShellHook
            extraStartup
            homeModules
            name
            stateVersion
            username
            ;
        }
      ) config.ai-tools.devshells;
    }
  );
}
