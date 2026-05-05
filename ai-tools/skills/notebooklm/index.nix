{ }:

{
  notebooklm = ''
    ---
    name: notebooklm
    description: Use NotebookLM for curated external knowledge bases, source-grounded synthesis, notebook management, and studio artifact generation.
    ---

    # NotebookLM

    Use this skill when the user wants to work with Google NotebookLM notebooks, sources, research, podcasts, reports, slides, or other NotebookLM artifacts.

    ## Tool Choice

    - If NotebookLM MCP tools are available directly, prefer them for notebook operations.
    - If NotebookLM MCP tools are not available but `nlm` is available, use the `nlm` CLI.
    - If both are available, prefer MCP for notebook actions and use `nlm` for login, diagnostics, and broader command help.
    - Use non-interactive commands from agent sessions; avoid interactive REPL commands such as `nlm chat start`.

    ## Best Uses

    - Curated external documentation or research collections.
    - Cross-source synthesis where NotebookLM citations are useful.
    - Generating NotebookLM audio, reports, slides, flashcards, quizzes, or infographics.
    - Keeping long-lived notebook libraries separate from local workspace memory.

    ## Rules

    - Authenticate before notebook work if auth is missing or stale.
    - Prefer `nlm login --check` before assuming auth is valid.
    - Ask before any delete action.
    - Include required confirmation flags for destructive or generation actions.
    - Prefer aliases for long notebook IDs once a notebook will be reused.
    - Do not say NotebookLM output was truncated unless the actual command/tool result says it was truncated.

    ## Good Patterns

    - Create notebook, then add sources with waiting enabled before querying.
    - Use NotebookLM for synthesized answers over uploaded sources; use local file tools for workspace files.
    - Use `source_get_content` or the CLI content command when the user wants raw source text instead of synthesis.
    - Poll artifact status only when needed; generation can take time.
    - For batch creation, pass titles as a comma-separated string such as `"MCP vs CLI Discussion"`, not as a JSON array string.

    ## Recovery

    - If NotebookLM returns auth errors, run `nlm login` and retry.
    - If MCP auth still looks stale after CLI login, refresh auth via the NotebookLM MCP auth tool if available.
    - If a command shape is unclear, use `nlm --help` or `nlm --ai`.
  '';
}
