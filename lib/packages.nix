{
  inputs,
  lib,
  pkgs,
}:
let
  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  upstreamMcpPackages = inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system};
  mcpNixosPackage = inputs.mcp-nixos.packages.${pkgs.stdenv.hostPlatform.system}.default;

  browserPackages =
    lib.optionals pkgs.stdenv.isLinux [ pkgs.chromium ]
    ++ lib.optionals pkgs.stdenv.isDarwin [ pkgs.google-chrome ];

  mkBundle =
    name: paths:
    pkgs.buildEnv {
      inherit name paths;
      ignoreCollisions = true;
    };

  sharedAgentPackages = [
    llmAgents.agent-browser
    llmAgents.claude-plugins
    pkgs.coreutils
    pkgs.jq
  ];

  serenaSupportPackages = [
    pkgs.gopls
    pkgs.nixd
    pkgs.rustup
    pkgs.zls
  ];

  claudeCodeHelperPackages = [ llmAgents.ccusage ];

  codexHelperPackages = [ llmAgents.ccusage-codex ];

  opencodeHelperPackages = [
    llmAgents.ccusage-opencode
    llmAgents.oh-my-opencode
  ];

  opencodeRuntimePackages = [
    pkgs.bash-language-server
    pkgs.nixfmt
    pkgs.pyright
    pkgs.terraform-ls
    pkgs.vscode-langservers-extracted
    pkgs.yaml-language-server
  ]
  ++ serenaSupportPackages;

  mcpRuntimePackages = [
    mcpNixosPackage
    upstreamMcpPackages.mcp-server-filesystem
    upstreamMcpPackages.mcp-server-git
    upstreamMcpPackages.mcp-server-memory
    upstreamMcpPackages.mcp-server-sequential-thinking
    upstreamMcpPackages.mcp-server-time
    upstreamMcpPackages.playwright-mcp
    upstreamMcpPackages.serena
  ]
  ++ browserPackages;

  toolPackages = {
    claudeCode = llmAgents.claude-code;
    codex = llmAgents.codex;
    opencode = llmAgents.opencode;
  };

  defaultPackages = lib.unique (
    sharedAgentPackages
    ++ serenaSupportPackages
    ++ claudeCodeHelperPackages
    ++ codexHelperPackages
    ++ opencodeHelperPackages
    ++ opencodeRuntimePackages
    ++ mcpRuntimePackages
    ++ [
      toolPackages.claudeCode
      toolPackages.codex
      toolPackages.opencode
    ]
  );
in
{
  inherit
    claudeCodeHelperPackages
    codexHelperPackages
    defaultPackages
    mcpRuntimePackages
    opencodeHelperPackages
    opencodeRuntimePackages
    serenaSupportPackages
    sharedAgentPackages
    toolPackages
    ;

  bundles = {
    default = mkBundle "ai-tools" defaultPackages;
    mcp = mkBundle "ai-tools-mcp" mcpRuntimePackages;
  };

  devShellPackages = lib.unique (defaultPackages ++ [ pkgs.home-manager ]);
}
