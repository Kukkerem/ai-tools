{
  inputs,
  lib,
  pkgs,
}:
let
  mcp = import ./mcp.nix { inherit inputs lib pkgs; };

  toOmp =
    server:
    if server ? url then
      {
        transport = server.transport or "http";
        url = server.url;
      }
    else
      {
        command = server.command;
      }
      // lib.optionalAttrs (server ? args && server.args != [ ]) { args = server.args; }
      // lib.optionalAttrs (server ? env && server.env != { }) { env = server.env; }
      // lib.optionalAttrs (server ? timeout) { timeout = server.timeout; };

  mapServers = transform: servers: lib.mapAttrs (_: transform) servers;

  jsonFormat = pkgs.formats.json { };
in
{
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
