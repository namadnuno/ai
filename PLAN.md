# Forge Memory — v1 Build Plan

Persistent codebase intelligence layer for forge. Token-efficient. Pull-only MCP.

## Scope (v1)

Forge installs an MCP server + rules dir + repo overview into target repo. Claude sessions auto-connect via `.mcp.json`. Three tools expose curated repo knowledge on demand. No code indexing yet — overview is hand-written. v2 will add AI-driven indexing.

Goal: Claude session gets the repo picture in one tool call (~500 tokens) instead of 20+ greps.

## Architecture

```
target-repo/
├── .agent/
│   ├── mcp/
│   │   ├── server.js          # stdio MCP, reads rules/overview
│   │   └── package.json       # @modelcontextprotocol/sdk
│   ├── rules/
│   │   └── *.md               # frontmatter: name, description, globs?
│   └── overview.md            # repo picture: stack, entry points, dirs
├── .mcp.json                  # points Claude at .agent/mcp/server.js
└── CLAUDE.md                  # stub: tells Claude to call repo_overview first
```

MCP runs on host (Node stdio), spawned per Claude session. Not in Docker (Claude Code runs on host).

## MCP tools

- `repo_overview()` → returns `.agent/overview.md` body
- `list_rules()` → returns `[{name, description, globs}]` from rule frontmatter
- `get_rule(name)` → returns rule body

## Rule format

```markdown
---
name: db-queries
description: All DB access goes through src/db/queries
globs: ["src/**/*.ts"]
---

Body explains the rule, examples, anti-patterns.
```

`globs` optional. `description` is what `list_rules` returns — must be self-explanatory so Claude can decide whether to pull body.

## Steps (each lands alone)

1. **MCP server** — `forge/mcp/server.js` + `package.json`. Node, `@modelcontextprotocol/sdk`. Implements 3 tools. Reads `.agent/overview.md` + `.agent/rules/*.md` from `cwd` (repo root). Frontmatter parser inline (no yaml dep — simple regex).
2. **Templates** — `forge/templates/overview.template.md`, `forge/templates/rule.template.md`, `forge/templates/mcp.json.template`, `forge/templates/claude-stub.template.md`.
3. **Install extension** — `forge/install.sh` writes `.mcp.json` at repo root, creates `.agent/rules/`, copies `overview.template.md` → `.agent/overview.md`, appends stub to repo `CLAUDE.md` (or creates it). Runs `npm install` in `.agent/mcp/`.
4. **Analyze stub** — `forge/analyze.sh`. v1: scaffolds rules dir + overview if missing, opens `$EDITOR`. v2 hook: AI pass.
5. **Skill** — `skills/forge-rule/SKILL.md`. Captures mid-session decisions into `.agent/rules/<name>.md`.
6. **Docs** — `forge/README.md` + repo `CLAUDE.md` (skills table row).

## Files

| Path | Action |
|---|---|
| `forge/mcp/server.js` | new |
| `forge/mcp/package.json` | new |
| `forge/install.sh` | modify |
| `forge/analyze.sh` | new |
| `forge/templates/overview.template.md` | new |
| `forge/templates/rule.template.md` | new |
| `forge/templates/mcp.json.template` | new |
| `forge/templates/claude-stub.template.md` | new |
| `skills/forge-rule/SKILL.md` | new |
| `forge/README.md` | modify |
| `CLAUDE.md` | modify |

## Test

- Install forge into scratch repo: `bash install.sh`
- Verify `.mcp.json`, `.agent/mcp/server.js`, `.agent/rules/`, `.agent/overview.md` exist
- `cd` in, run `claude`. `/mcp` lists `forge` connected
- Ask "what does this repo do" — Claude calls `repo_overview`, not bulk greps
- Add rule with glob `*.ts`. Edit `.ts` file. Claude calls `get_rule` before writing

## Deferred (v2)

- AI-driven `analyze` — real codebase indexing (feature B)
- Symbol search / vector embeds (sqlite-vec / tree-sitter)
- Auto-update on file changes
- Hybrid Cursor-style auto-attach beyond glob metadata
- Memory of past sessions / decisions log

## Anti-patterns to avoid

- Auto-loading rules into every turn (defeats token efficiency goal)
- Heavy deps in MCP server (keep `@modelcontextprotocol/sdk` only)
- Adding tree-sitter / vector DB in v1 (defer to v2)
- Coupling memory layer to programmer/reviewer pipeline (must stay independent)
