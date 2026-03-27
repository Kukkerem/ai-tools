{
  inputs,
  lib,
  pkgs,
}:
let
  mcpPackages = inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system};
  mcpNixosPackage = inputs.mcp-nixos.packages.${pkgs.stdenv.hostPlatform.system}.default;

  mkServers =
    {
      enabledServerNames,
      filesystemAllowedPaths,
      memoryBaseDir,
      memoryDir,
      serenaExtraArgs ? [ ],
    }:
    let
      availableServers = {
        sequential-thinking = {
          command = lib.getExe mcpPackages.mcp-server-sequential-thinking;
        };

        git = {
          command = lib.getExe mcpPackages.mcp-server-git;
        };

        nixos = {
          command = lib.getExe mcpNixosPackage;
        };

        time = {
          command = lib.getExe mcpPackages.mcp-server-time;
        };

        memory = {
          command = lib.getExe mcpPackages.mcp-server-memory;
          env = {
            MEMORY_FILE_PATH = "${memoryBaseDir}/${memoryDir}/memory.json";
          };
        };

        serena = {
          command = lib.getExe' mcpPackages.serena "serena-mcp-server";
          args = [
            "--context"
            "ide-assistant"
            "--enable-web-dashboard"
            "False"
          ]
          ++ serenaExtraArgs;
        };

        playwright = {
          command = lib.getExe mcpPackages.playwright-mcp;
          args = [
            "--executable-path"
          ]
          ++ lib.optionals pkgs.stdenv.isLinux [ (lib.getExe pkgs.chromium) ]
          ++ lib.optionals pkgs.stdenv.isDarwin [ (lib.getExe pkgs.google-chrome) ];
        };

        filesystem = {
          command = lib.getExe mcpPackages.mcp-server-filesystem;
          args = filesystemAllowedPaths;
        };
      };
    in
    lib.filterAttrs (name: _: builtins.elem name enabledServerNames) availableServers;

  toClaudeCode =
    server:
    {
      type = "stdio";
      command = server.command;
    }
    // lib.optionalAttrs (server ? args && server.args != [ ]) { args = server.args; }
    // lib.optionalAttrs (server ? env && server.env != { }) { environment = server.env; };

  toOpenCode =
    server:
    {
      type = "local";
      enabled = true;
      command = [ server.command ] ++ (server.args or [ ]);
    }
    // lib.optionalAttrs (server ? env && server.env != { }) { environment = server.env; };

  toCodex =
    server:
    {
      command = server.command;
    }
    // lib.optionalAttrs (server ? args && server.args != [ ]) { args = server.args; }
    // lib.optionalAttrs (server ? env && server.env != { }) { env = server.env; };

  mapServers = transform: servers: lib.mapAttrs (_: transform) servers;
in
{
  forClaudeCode =
    {
      enabledServerNames,
      filesystemAllowedPaths,
      memoryBaseDir,
      memoryDir,
    }:
    mapServers toClaudeCode (mkServers {
      inherit
        enabledServerNames
        filesystemAllowedPaths
        memoryBaseDir
        memoryDir
        ;
      serenaExtraArgs = [
        "--project"
        "$(pwd)"
      ];
    });

  forOpenCode =
    {
      enabledServerNames,
      filesystemAllowedPaths,
      memoryBaseDir,
      memoryDir,
    }:
    mapServers toOpenCode (mkServers {
      inherit
        enabledServerNames
        filesystemAllowedPaths
        memoryBaseDir
        memoryDir
        ;
    });

  forCodex =
    {
      enabledServerNames,
      filesystemAllowedPaths,
      memoryBaseDir,
      memoryDir,
    }:
    mapServers toCodex (mkServers {
      inherit
        enabledServerNames
        filesystemAllowedPaths
        memoryBaseDir
        memoryDir
        ;
    });
}
