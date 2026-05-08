<!-- forge:memory:start -->
## Forge memory (MCP `forge`)

This repo ships a memory MCP server. Use it to skip cold-start scans.

- **At session start**, call `repo_overview` once to get stack, entry points, key dirs, conventions.
- **Before editing any file**, call `pre_edit` with the file path. It returns full bodies of all matching rules in one call. Act on any rules returned before proceeding.
- **Do not** bulk-grep the codebase to derive things `repo_overview` already states.

Rules live in `.agent/rules/`. Overview lives in `.agent/overview.md`. Edit directly or run `./.agent/analyze.sh` to scaffold.
<!-- forge:memory:end -->
