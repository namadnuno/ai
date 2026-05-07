<!-- forge:memory:start -->
## Forge memory (MCP `forge`)

This repo ships a memory MCP server. Use it to skip cold-start scans.

- **At session start**, call `repo_overview` once to get stack, entry points, key dirs, conventions.
- **Before editing files**, call `list_rules` (cheap — names + descriptions + globs only). If a rule's globs match the file you're about to touch, call `get_rule` to read the body.
- **Do not** bulk-grep the codebase to derive things `repo_overview` already states.

Rules live in `.agent/rules/`. Overview lives in `.agent/overview.md`. Edit directly or run `./.agent/analyze.sh` to scaffold.
<!-- forge:memory:end -->
