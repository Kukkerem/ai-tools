{ }:

{
  basic-memory = ''
    ---
    name: basic-memory
    description: Local-first Markdown knowledge base with MCP server. Use when you need persistent knowledge storage, retrieval, or cross-session memory management.
    ---

    # Basic Memory

    Use this skill when the task requires persistent memory or knowledge management.

    ## When To Use

    - Store important decisions, context, or knowledge for future sessions.
    - Retrieve previously stored information by semantic search.
    - Build knowledge graphs from notes with observations and relations.
    - Manage multiple memory projects for different contexts.
    - Create structured notes with YAML frontmatter and tagged observations.

    ## Key Concepts

    - **Project**: A named knowledge base (default: `main`). Switch projects with `--project` or `BASIC_MEMORY_PROJECT` env var.
    - **Note**: A Markdown file with YAML frontmatter, observations (bullet points), and relations (links to other notes).
    - **Search**: Full-text and semantic search across all notes in a project.
    - **Build Context**: Generate comprehensive context from a note and its related notes.
    - **Schema**: Notes follow a structured format: frontmatter → observations → relations.

    ## Preferred Approach

    - Use `basic_memory_*` MCP tools when available in the session.
    - Prefer `build_context` for retrieving comprehensive information about a topic.
    - Use `write_note` for storing decisions, findings, and important context.
    - Use `search_notes` for finding relevant information across the knowledge base.
    - Use `recent_activity` to see what has changed recently.

    ## Notes

    - Basic Memory is local-first — all data stays on your machine as Markdown files.
    - Project path is configured via `BASIC_MEMORY_HOME` or `BASIC_MEMORY_CONFIG_DIR` env vars.
    - The `--project` flag or `BASIC_MEMORY_PROJECT` env var selects which project to use.
    - Use `list_memory_projects` and `create_memory_project` for managing multiple projects.
  '';
}
