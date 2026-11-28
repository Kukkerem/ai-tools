{
  inputs,
  lib,
  pkgs,
}:
let
  mcp = import ./mcp.nix { inherit inputs lib pkgs; };

  # omp-native keys valid on every transport. omp expands `${VAR:-default}` in
  # all string values at discovery, `enabled` included, so a string such as
  # "\${MY_MCP:-false}" lets an environment variable switch a server on.
  ompCommonKeys = [
    "enabled"
    "instructions"
  ];

  toOmp =
    server:
    (
      if server ? url then
        {
          transport = server.transport or "http";
          url = server.url;
        }
        // lib.optionalAttrs (server ? headers && server.headers != { }) { headers = server.headers; }
      else
        {
          command = server.command;
        }
        // lib.optionalAttrs (server ? args && server.args != [ ]) { args = server.args; }
        // lib.optionalAttrs (server ? env && server.env != { }) { env = server.env; }
        // lib.optionalAttrs (server ? timeout) { timeout = server.timeout; }
    )
    // lib.filterAttrs (key: _: lib.elem key ompCommonKeys) server;

  mapServers = transform: servers: lib.mapAttrs (_: transform) servers;

  jsonFormat = pkgs.formats.json { };
in
{
  inherit toOmp;

  forOmp =
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
    let
      servers = mapServers toOmp (
        mcp.mkServers {
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
        }
      );
    in
    jsonFormat.generate "omp-mcp" {
      mcpServers = servers;
      disabledServers = [ ];
    };
}
