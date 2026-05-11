<!-- forge:memory:start -->
## Forge memory (MCP `forge`)

This repo ships a memory MCP server. Use it to skip cold-start scans.

- **At session start**, call `repo_overview` once to get stack, entry points, key dirs, conventions.
- **Before editing any file**, call `pre_edit` with the file path. It returns full bodies of all matching rules in one call. Act on any rules returned before proceeding.
- **Do not** bulk-grep the codebase to derive things `repo_overview` already states.

Rules live in `.agent/rules/`. Overview lives in `.agent/overview.md`. Edit directly or run `./.agent/analyze.sh` to scaffold.

### REQUIRED: rule enforcement on every file edit

Before calling Edit, Write, or any file-modification tool:
1. Call `mcp__forge__pre_edit` with the target file path.
2. Read every rule returned. Rules are **mandatory** — not advisory.
3. If a rule conflicts with the task, surface the conflict explicitly before proceeding.
4. Never skip `pre_edit` to save time. No exceptions.

If `pre_edit` returns no rules, proceed. If MCP is unavailable, state it and continue — but do not silently skip the step.
<!-- forge:memory:end -->
