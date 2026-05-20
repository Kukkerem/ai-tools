{
  inputs,
  lib,
  pkgs,
}:
let
  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  openclawTools = inputs.nix-openclaw-tools.packages.${pkgs.stdenv.hostPlatform.system};
  upstreamMcpPackages = inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system};
  mcpNixosPackage = inputs.mcp-nixos.packages.${pkgs.stdenv.hostPlatform.system}.default;
  mcpSupport = import ./mcp.nix { inherit inputs lib pkgs; };

  browserPackages =
    lib.optionals pkgs.stdenv.isLinux [ pkgs.chromium ]
    ++ lib.optionals pkgs.stdenv.isDarwin [ pkgs.google-chrome ];

  cavemanSkillRuntimePackages = [
    (pkgs.python3.withPackages (ps: [
      ps.anthropic
      ps.tiktoken
    ]))
  ];
  gogSkillRuntimePackages = [ openclawTools.gogcli ];

  superpowersSkillRuntimePackages = [
    pkgs.nodejs
    pkgs.graphviz
    pkgs.which
    pkgs.findutils
  ];

  agentBrowserSkillRuntimePackages = browserPackages;

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

  # Core language server support for Serena code intelligence.
  serenaSupportPackages = [
    pkgs.gopls
    pkgs.nixd
  ];

  # Rust toolchain for Serena Rust project support. Included in the devshell bundle
  # but not automatically added by the HM module unless explicitly requested via
  # `home.packages`. Users who need Rust support should add these via
  # `home.packages = with pkgs; [ rustup zls ];` or enable via the module option.
  serenaRustPackages = [
    pkgs.rustup
    pkgs.zls
  ];

  claudeCodeHelperPackages = [ llmAgents.ccusage ];

  codexHelperPackages = [ ];

  opencodeHelperPackages = [ ];

  ompHelperPackages = [ ];

  opencodeRuntimePackages = [
    pkgs.bash-language-server
    pkgs.nixfmt
    pkgs.pyright
    pkgs.terraform-ls
    pkgs.vscode-langservers-extracted
    pkgs.yaml-language-server
  ]
  ++ serenaSupportPackages
  ++ serenaRustPackages;

  mcpRuntimePackages = [
    mcpSupport.basicMemoryPackage
    mcpSupport.mcpServerFetchFixed
    mcpSupport.notebooklmPackage
    mcpNixosPackage
    pkgs.terraform-mcp-server
    pkgs.uv
    upstreamMcpPackages.context7-mcp
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
    omp = llmAgents.omp;
  };

  defaultPackages = lib.unique (
    sharedAgentPackages
    ++ serenaSupportPackages
    ++ serenaRustPackages
    ++ claudeCodeHelperPackages
    ++ codexHelperPackages
    ++ opencodeHelperPackages
    ++ opencodeRuntimePackages
    ++ mcpRuntimePackages
    ++ [
      toolPackages.claudeCode
      toolPackages.codex
      toolPackages.opencode
      toolPackages.omp
    ]
  );
in
{
  inherit
    agentBrowserSkillRuntimePackages
    cavemanSkillRuntimePackages
    claudeCodeHelperPackages
    codexHelperPackages
    defaultPackages
    mcpRuntimePackages
    ompHelperPackages
    opencodeHelperPackages
    opencodeRuntimePackages
    serenaRustPackages
    serenaSupportPackages
    sharedAgentPackages
    superpowersSkillRuntimePackages
    toolPackages
    gogSkillRuntimePackages
    ;

  bundles = {
    default = mkBundle "ai-tools" defaultPackages;
    mcp = mkBundle "ai-tools-mcp" mcpRuntimePackages;
  };

  devShellPackages = lib.unique (defaultPackages ++ [ pkgs.home-manager ]);
}
