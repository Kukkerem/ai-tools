{ }:

{
  rtk = ''
    ---
    name: rtk
    description: RTK token saver — transparently compresses shell command outputs to reduce LLM token consumption. Runs automatically as a plugin hook.
    ---

    # RTK — Reduce Token Karma

    Use this skill to understand how RTK optimizes token usage in your sessions.

    ## How It Works

    RTK automatically intercepts `bash` and `shell` tool calls in OpenCode:
    - Rewrites commands like `git status` → `rtk git status`
    - Runs the real command via the RTK proxy
    - Returns compressed/filtered output to save tokens
    - Tracks cumulative savings with `rtk gain` and `rtk discover`

    ## Key Commands

    - `rtk gain` — Show token savings so far.
    - `rtk discover` — Show which commands are being rewritten.
    - `rtk init -g --opencode` — Install the OpenCode plugin when not managed by this module.

    ## Configuration

    RTK config lives at `~/.config/rtk/config.toml`:
    ```toml
    [hooks]
    exclude_commands = []

    [tee]
    enabled = true
    mode = "failures"

    [telemetry]
    enabled = false
    ```

    ## Notes

    - RTK is transparent — no manual action needed during sessions.
    - The OpenCode plugin hooks `tool.execute.before` for bash/shell only.
    - MCP tools and non-shell tools are not affected.
    - Set `RTK_DISABLED=1` to temporarily disable.
    - This module wraps `rtk` with `LC_ALL=C` to avoid locale-sensitive command behavior.
  '';
}
