{ }:

{
  dcp = ''
    ---
    name: dcp
    description: Dynamic Context Pruning for OpenCode. Use when context window is getting large and you need to compress or prune stale content without losing critical state.
    ---

    # DCP — Dynamic Context Pruning

    Use this skill when context management is needed during long sessions.

    ## When To Use

    - Context window is approaching limits (auto-nudge will trigger).
    - You want to compress contiguous tool output spans.
    - You need to deduplicate repeated tool calls.
    - You want to purge stale errored tool inputs.

    ## Key Commands

    - `/dcp` — Main command for manual pruning operations.
    - `/dcp sweep` — Remove stale content from context.
    - `/dcp compress` — Compress tool output ranges.

    ## How It Works

    - **Range mode**: Compresses contiguous spans of tool outputs into summaries.
    - **Message mode**: Compresses individual raw messages.
    - **Deduplication**: Removes duplicate tool call results.
    - **Purge Errors**: Removes old errored tool inputs after N turns.
    - Session history is NEVER modified — only what is sent to the model changes.

    ## Protected Tools

    The following tool outputs are protected from pruning/compression:
    - `task_*` — task management state
    - `memory_*` — knowledge graph state
    - `session_*` — session tracking
    - `serena_*` — code intelligence
    - `notebooklm_*` — notebook queries
    - `basic_memory_*` — persistent memory

    ## Notes

    - DCP runs as a plugin — no MCP server needed.
    - Auto-nudge triggers when context approaches limits.
    - Protected tools are additive — project config adds to defaults.
  '';
}
