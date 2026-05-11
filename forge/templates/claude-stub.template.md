<!-- forge:memory:start -->
## Forge memory (MCP `forge`)

This repo ships a memory MCP server. Use it to skip cold-start scans.

**Session start — always do both:**
1. `repo_overview` — stack, entry points, dirs, conventions (~500 tokens, one call)
2. `list_context` — accumulated cross-session insights (keys only, cheap). Pull bodies with `get_context(scope)` only for areas you're about to work in.

**Searching — use index, not filesystem:**
- `search_files(pattern)` — glob match against indexed files (respects .gitignore)
- `search_content(query)` — FTS5 ranked search across file contents

Do not bulk-grep or tree-walk the codebase for things these tools can answer.

**After learning something non-obvious:**
Call `save_context(scope, key, body)` — persists insight for future sessions.
- `scope`: file path or `__project__`
- `key`: `overview` | `patterns` | `gotchas` | `why` | `deps`
- `body`: 1-3 sentences. Non-obvious only — not what the code does.

Rules live in `.agent/rules/`. Overview lives in `.agent/overview.md`.

### REQUIRED: before every file edit

Before calling Edit, Write, or any file-modification tool:
1. Call `pre_edit(path)` — returns all matching rules. Rules are **mandatory**.
2. Call `get_context(path)` — returns saved insights for that file. Act on any returned.
3. If a rule or insight conflicts with the task, surface it explicitly before proceeding.
4. Never skip either call. No exceptions.

If MCP is unavailable, state it and continue — but do not silently skip the steps.
<!-- forge:memory:end -->
