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

## Feature B: File Index DB

Adds incremental SQLite index of repo files. Gitignore-aware. Enables fast file + content search via MCP.

### Why

`repo_overview` covers hand-written context. File search covers the codebase itself. Together they replace cold-start greps.

### Stack

- **`better-sqlite3`** — sync, embedded, no extra process
- **`git ls-files -co --exclude-standard`** — git handles gitignore natively, no custom parsing
- **SQLite FTS5** — content search with BM25 ranking, built-in

### DB location

`.agent/index.db` — gitignored (add to `.gitignore` on install)

### Schema

```sql
CREATE TABLE IF NOT EXISTS files (
  path TEXT PRIMARY KEY,
  mtime INTEGER NOT NULL,
  size  INTEGER NOT NULL,
  hash  TEXT NOT NULL,
  content TEXT
) STRICT;

CREATE VIRTUAL TABLE IF NOT EXISTS files_fts USING fts5(
  path, content,
  content=files,
  content_rowid=rowid
);

-- FTS sync triggers
CREATE TRIGGER files_ai AFTER INSERT ON files BEGIN
  INSERT INTO files_fts(rowid, path, content) VALUES (new.rowid, new.path, new.content);
END;
CREATE TRIGGER files_ad AFTER DELETE ON files BEGIN
  INSERT INTO files_fts(files_fts, rowid, path, content) VALUES ('delete', old.rowid, old.path, old.content);
END;
CREATE TRIGGER files_au AFTER UPDATE ON files BEGIN
  INSERT INTO files_fts(files_fts, rowid, path, content) VALUES ('delete', old.rowid, old.path, old.content);
  INSERT INTO files_fts(rowid, path, content) VALUES (new.rowid, new.path, new.content);
END;
```

### Indexer module — `indexer.js`

```
export function openDb(root)       // opens/creates .agent/index.db, runs migrations
export function syncIndex(root, db) // incremental: git ls-files → mtime check → upsert changed
export function closeDb(db)
```

**Sync flow:**

1. `git ls-files -co --exclude-standard` → current file list
2. Compare each path against DB row (mtime + size). Skip unchanged.
3. Changed/new: read content, compute sha256 hex, upsert row → triggers update FTS.
4. Deleted: delete row from `files` → trigger removes from FTS.

Skip binary files (check for null bytes in first 8KB).

### New MCP tools

| Tool | Input | Returns |
|---|---|---|
| `search_files` | `pattern: string` (glob) | Array of matching paths from index |
| `search_content` | `query: string`, `limit?: number (default 20)` | FTS5 ranked results: `[{path, excerpt, rank}]` |

Both tools trigger `syncIndex` before querying so results are fresh.

`search_content` uses `snippet()` function for excerpt. Max 20 results by default.

### New files

| Path | Action |
|---|---|
| `forge/mcp/indexer.js` | new |
| `forge/mcp/package.json` | add `better-sqlite3` dep |
| `forge/mcp/server.js` | add `search_files` + `search_content` tools |
| `forge/install.sh` | add `.agent/index.db` to `.gitignore` |

### Test

- Install forge into scratch repo, run `index_repo` or trigger search
- Modify a tracked file, call `search_content` — returns updated content
- Add file, verify it appears. Delete file, verify it's gone.
- Verify `node_modules/` and gitignored paths never appear in results

## Deferred (v3)

- Symbol search / vector embeds (sqlite-vec / tree-sitter)
- Auto-update on file changes (fs.watch or inotify)
- Hybrid Cursor-style auto-attach beyond glob metadata
- Memory of past sessions / decisions log

## Anti-patterns to avoid

- Auto-loading rules into every turn (defeats token efficiency goal)
- Parsing `.gitignore` manually — use `git ls-files` instead
- Storing binary file content in DB
- Blocking MCP response on full re-index (sync is incremental, fast)
- Coupling memory layer to programmer/reviewer pipeline (must stay independent)
