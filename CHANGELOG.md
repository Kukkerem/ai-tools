# Changelog

All notable changes to this project will be documented in this file.

This file is auto-generated from conventional commits using
[git-cliff](https://git-cliff.org/). Run `git cliff` locally or see the
[GitHub release notes](https://github.com/zolszabo/ai-tools/releases) for
the rendered changelog per version.

<!-- git-cliff-start -->
## [0.1.0] - unreleased

### Features

- Initial release of `ai-tools` flake
- Home Manager module (`programs.ai-tools`) with options for Claude Code, Codex, and OpenCode
- MCP server integration (sequential-thinking, git, time, memory, serena, filesystem, and more)
- `nix develop` devshell with pre-configured AI tool environment
- Flake-parts module (`flakeModules.ai-tools-devshell`) for multi-project consumption
- `nixosModules.ai-tools` for NixOS + home-manager configurations
- RTK (token-saver) integration via `llm-agents` input
- DCP (dynamic context pruning) plugin for OpenCode
- Caveman skill bundle (caveman, caveman-commit, caveman-compress, and friends)
- Release automation: `scripts/release.sh`, CI/CD workflows, Cachix caching
<!-- git-cliff-end -->
