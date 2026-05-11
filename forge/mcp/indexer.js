import Database from "better-sqlite3";
import { createHash } from "node:crypto";
import { readFileSync, statSync } from "node:fs";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

const DB_RELATIVE = ".agent/index.db";
const SYNC_TTL_MS = 30_000;

function isBinary(buf) {
  const end = Math.min(buf.length, 8192);
  for (let i = 0; i < end; i++) if (buf[i] === 0) return true;
  return false;
}

function sha256hex(str) {
  return createHash("sha256").update(str).digest("hex");
}

const SCHEMA = `
  CREATE TABLE IF NOT EXISTS meta (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS files (
    path    TEXT PRIMARY KEY,
    mtime   INTEGER NOT NULL,
    size    INTEGER NOT NULL,
    hash    TEXT NOT NULL,
    content TEXT
  ) STRICT;

  CREATE VIRTUAL TABLE IF NOT EXISTS files_fts USING fts5(
    path, content,
    content=files,
    content_rowid=rowid
  );

  CREATE TRIGGER IF NOT EXISTS files_ai AFTER INSERT ON files BEGIN
    INSERT INTO files_fts(rowid, path, content) VALUES (new.rowid, new.path, new.content);
  END;
  CREATE TRIGGER IF NOT EXISTS files_ad AFTER DELETE ON files BEGIN
    INSERT INTO files_fts(files_fts, rowid, path, content) VALUES ('delete', old.rowid, old.path, old.content);
  END;
  CREATE TRIGGER IF NOT EXISTS files_au AFTER UPDATE ON files BEGIN
    INSERT INTO files_fts(files_fts, rowid, path, content) VALUES ('delete', old.rowid, old.path, old.content);
    INSERT INTO files_fts(rowid, path, content) VALUES (new.rowid, new.path, new.content);
  END;

  CREATE TABLE IF NOT EXISTS context (
    scope   TEXT NOT NULL,
    key     TEXT NOT NULL,
    body    TEXT NOT NULL,
    updated INTEGER NOT NULL,
    PRIMARY KEY (scope, key)
  );
`;

export function openDb(root) {
  const db = new Database(resolve(root, DB_RELATIVE));
  db.pragma("journal_mode = WAL");
  db.pragma("synchronous = NORMAL");
  db.pragma("temp_store = MEMORY");
  db.pragma("mmap_size = 268435456");
  db.exec(SCHEMA);
  return db;
}

export function closeDb(db) {
  db.close();
}

export function syncIndex(root, db) {
  const lastSynced = db.prepare("SELECT value FROM meta WHERE key = 'last_synced'").get();
  if (lastSynced && Date.now() - parseInt(lastSynced.value) < SYNC_TTL_MS) {
    return { indexed: 0, skipped: 0, deleted: 0, cached: true };
  }

  const r = spawnSync("git", ["ls-files", "-co", "--exclude-standard"], {
    cwd: root,
    encoding: "utf8",
    maxBuffer: 10 * 1024 * 1024,
  });
  if (r.error || r.status !== 0) return { indexed: 0, skipped: 0, deleted: 0 };

  const currentPaths = new Set(r.stdout.split("\n").filter(Boolean));

  const getRow = db.prepare("SELECT mtime, size FROM files WHERE path = ?");
  const upsert = db.prepare(`
    INSERT INTO files (path, mtime, size, hash, content) VALUES (@path, @mtime, @size, @hash, @content)
    ON CONFLICT(path) DO UPDATE SET
      mtime=excluded.mtime, size=excluded.size, hash=excluded.hash, content=excluded.content
  `);
  const del = db.prepare("DELETE FROM files WHERE path = ?");
  const setMeta = db.prepare("INSERT OR REPLACE INTO meta (key, value) VALUES ('last_synced', ?)");

  let indexed = 0, skipped = 0, deleted = 0;

  db.transaction(() => {
    for (const relPath of currentPaths) {
      let st;
      try { st = statSync(join(root, relPath)); } catch { continue; }

      const mtime = Math.floor(st.mtimeMs);
      const size = st.size;
      const row = getRow.get(relPath);
      if (row && row.mtime === mtime && row.size === size) { skipped++; continue; }

      let buf;
      try { buf = readFileSync(join(root, relPath)); } catch { continue; }
      if (isBinary(buf)) { skipped++; continue; }

      const content = buf.toString("utf8");
      upsert.run({ path: relPath, mtime, size, hash: sha256hex(content), content });
      indexed++;
    }

    for (const { path } of db.prepare("SELECT path FROM files").all()) {
      if (!currentPaths.has(path)) { del.run(path); deleted++; }
    }

    setMeta.run(String(Date.now()));
  })();

  return { indexed, skipped, deleted };
}

export function getAllPaths(db) {
  return db.prepare("SELECT path FROM files ORDER BY path").all().map((r) => r.path);
}

export function searchContent(db, query, limit = 20) {
  return db.prepare(`
    SELECT f.path,
           snippet(files_fts, 1, '[', ']', '...', 32) AS excerpt,
           rank
    FROM files_fts
    JOIN files f ON f.rowid = files_fts.rowid
    WHERE files_fts MATCH ?
    ORDER BY rank
    LIMIT ?
  `).all(query, limit);
}

export function saveContext(db, scope, key, body) {
  db.prepare(`
    INSERT INTO context (scope, key, body, updated) VALUES (?, ?, ?, ?)
    ON CONFLICT(scope, key) DO UPDATE SET body=excluded.body, updated=excluded.updated
  `).run(scope, key, body, Date.now());
}

export function listContext(db) {
  return db.prepare("SELECT scope, key, updated FROM context ORDER BY scope, key").all();
}

export function getContext(db, scope) {
  if (scope) {
    return db.prepare("SELECT key, body, updated FROM context WHERE scope = ? ORDER BY key").all(scope);
  }
  return db.prepare("SELECT scope, key, body, updated FROM context ORDER BY scope, key").all();
}
