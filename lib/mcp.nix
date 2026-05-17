{
  inputs,
  lib,
  pkgs,
}:
let
  mcpPackages = inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system};
  mcpNixosPackage = inputs.mcp-nixos.packages.${pkgs.stdenv.hostPlatform.system}.default;
  openrouterSearchPackage =
    inputs.mcp-openrouter-search.packages.${pkgs.stdenv.hostPlatform.system}.default;

  mcpServerFetchFixed = mcpPackages.mcp-server-fetch.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/mcp_server_fetch/server.py --replace 'proxies=proxy_url' 'proxy=proxy_url'
    '';
    pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "httpx" ];
  });

  notebooklmPackage = pkgs.symlinkJoin {
    name = "notebooklm-mcp-cli";
    paths = [
      (pkgs.writeShellScriptBin "notebooklm-mcp" ''
        export UV_PYTHON_DOWNLOADS=never
        exec ${lib.getExe pkgs.uv} tool run --python ${lib.getExe pkgs.python3} --from notebooklm-mcp-cli==0.6.9 notebooklm-mcp "$@"
      '')
      (pkgs.writeShellScriptBin "nlm" ''
        export UV_PYTHON_DOWNLOADS=never
        exec ${lib.getExe pkgs.uv} tool run --python ${lib.getExe pkgs.python3} --from notebooklm-mcp-cli==0.6.9 nlm "$@"
      '')
    ];
  };

  basicMemoryPackage = pkgs.symlinkJoin {
    name = "basic-memory-mcp-cli";
    paths = [
      (pkgs.writeShellScriptBin "basic-memory" ''
        export BASIC_MEMORY_NO_PROMOS=1
        export BASIC_MEMORY_FORCE_LOCAL=true
        export UV_PYTHON_DOWNLOADS=never
        exec ${lib.getExe pkgs.uv} tool run --python ${lib.getExe pkgs.python3} --from basic-memory==0.21.1 basic-memory "$@"
      '')
      (pkgs.writeShellScriptBin "basic-memory-mcp" ''
        export BASIC_MEMORY_NO_PROMOS=1
        export BASIC_MEMORY_FORCE_LOCAL=true
        export UV_PYTHON_DOWNLOADS=never
        exec ${lib.getExe pkgs.uv} tool run --python ${lib.getExe pkgs.python3} --from basic-memory==0.21.1 basic-memory mcp "$@"
      '')
    ];
  };

  mkOpenRouterSearchServer =
    {
      apiKey ? null,
      apiKeyFile ? null,
      env ? { },
    }:
    let
      openrouterEnv =
        (lib.optionalAttrs (apiKey != null) { OPENROUTER_API_KEY = apiKey; })
        // (lib.optionalAttrs (apiKeyFile != null) { OPENROUTER_API_KEY_FILE = apiKeyFile; })
        // env;
    in
    {
      command = lib.getExe openrouterSearchPackage;
      args = [
        "--timeout-ms"
        "300000"
      ];
      timeout = 300000;
    }
    // lib.optionalAttrs (openrouterEnv != { }) {
      env = openrouterEnv;
    };

  mkServers =
    {
      enabledServerNames,
      filesystemAllowedPaths,
      memoryBaseDir,
      memoryDir,
      qmdUrl ? null,
      openrouterSearchApiKey ? null,
      openrouterSearchApiKeyFile ? null,
      openrouterSearchEnv ? { },
      serverOverrides ? { },
      extraServers ? { },
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

        context7 = {
          command = lib.getExe mcpPackages.context7-mcp;
        };

        nixos = {
          command = lib.getExe mcpNixosPackage;
        };

        time = {
          command = lib.getExe mcpPackages.mcp-server-time;
        };

        fetch = {
          command = lib.getExe mcpServerFetchFixed;
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

        notebooklm = {
          command = lib.getExe' notebooklmPackage "notebooklm-mcp";
        };

        basic-memory = {
          command = lib.getExe' basicMemoryPackage "basic-memory-mcp";
        };

        terraform = {
          command = lib.getExe pkgs.terraform-mcp-server;
        };

        qmd = {
          url = qmdUrl;
        };

        deepwiki = {
          url = "https://mcp.deepwiki.com/mcp";
        };

        exa = {
          url = "https://mcp.exa.ai/mcp";
        };

        openrouter-search = mkOpenRouterSearchServer {
          apiKey = openrouterSearchApiKey;
          apiKeyFile = openrouterSearchApiKeyFile;
          env = openrouterSearchEnv;
        };
      };

      overriddenServers = availableServers // serverOverrides;
      enabledServers = lib.filterAttrs (name: _: builtins.elem name enabledServerNames) overriddenServers;
    in
    enabledServers // extraServers;

  toClaudeCode =
    server:
    if server ? url then
      {
        type = server.transport or "http";
        url = server.url;
      }
    else
      {
        type = "stdio";
        command = server.command;
      }
      // lib.optionalAttrs (server ? args && server.args != [ ]) { args = server.args; }
      // lib.optionalAttrs (server ? env && server.env != { }) { environment = server.env; };

  toOpenCode =
    server:
    if server ? url then
      {
        type = "remote";
        enabled = true;
        url = server.url;
      }
    else
      {
        type = "local";
        enabled = true;
        command = [ server.command ] ++ (server.args or [ ]);
      }
      // lib.optionalAttrs (server ? env && server.env != { }) { environment = server.env; }
      // lib.optionalAttrs (server ? timeout) { timeout = server.timeout; };

  toCodex =
    server:
    if server ? url then
      { serverUrl = server.url; }
    else
      {
        command = server.command;
      }
      // lib.optionalAttrs (server ? args && server.args != [ ]) { args = server.args; }
      // lib.optionalAttrs (server ? env && server.env != { }) { env = server.env; };

  mapServers = transform: servers: lib.mapAttrs (_: transform) servers;
in
{
  inherit
    basicMemoryPackage
    mcpServerFetchFixed
    mkServers
    notebooklmPackage
    ;

  forClaudeCode =
    {
      enabledServerNames,
      filesystemAllowedPaths,
      memoryBaseDir,
      memoryDir,
      qmdUrl ? null,
      openrouterSearchApiKey ? null,
      openrouterSearchApiKeyFile ? null,
      openrouterSearchEnv ? { },
      serverOverrides ? { },
      extraServers ? { },
    }:
    mapServers toClaudeCode (mkServers {
      inherit
        enabledServerNames
        filesystemAllowedPaths
        memoryBaseDir
        memoryDir
        qmdUrl
        openrouterSearchApiKey
        openrouterSearchApiKeyFile
        openrouterSearchEnv
        serverOverrides
        extraServers
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
      qmdUrl ? null,
      openrouterSearchApiKey ? null,
      openrouterSearchApiKeyFile ? null,
      openrouterSearchEnv ? { },
      serverOverrides ? { },
      extraServers ? { },
    }:
    mapServers toOpenCode (mkServers {
      inherit
        enabledServerNames
        filesystemAllowedPaths
        memoryBaseDir
        memoryDir
        qmdUrl
        openrouterSearchApiKey
        openrouterSearchApiKeyFile
        openrouterSearchEnv
        serverOverrides
        extraServers
        ;
    });

  forCodex =
    {
      enabledServerNames,
      filesystemAllowedPaths,
      memoryBaseDir,
      memoryDir,
      qmdUrl ? null,
      openrouterSearchApiKey ? null,
      openrouterSearchApiKeyFile ? null,
      openrouterSearchEnv ? { },
      serverOverrides ? { },
      extraServers ? { },
    }:
    mapServers toCodex (mkServers {
      inherit
        enabledServerNames
        filesystemAllowedPaths
        memoryBaseDir
        memoryDir
        qmdUrl
        openrouterSearchApiKey
        openrouterSearchApiKeyFile
        openrouterSearchEnv
        serverOverrides
        extraServers
        ;
    });
}
