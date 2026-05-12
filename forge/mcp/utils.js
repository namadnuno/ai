import { readFile, readdir, stat } from "node:fs/promises";
import { join, basename } from "node:path";

/** @param {string} path @returns {Promise<string | null>} */
export async function readIfExists(path) {
  try {
    return await readFile(path, "utf8");
  } catch (err) {
    if (err.code === "ENOENT") return null;
    throw err;
  }
}

/** @param {string} src @returns {FrontmatterResult} */
export function parseFrontmatter(src) {
  const match = src.match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/);
  if (!match) return { meta: {}, body: src };
  const meta = {};
  for (const line of match[1].split("\n")) {
    const m = line.match(/^([a-zA-Z_][\w-]*)\s*:\s*(.*)$/);
    if (!m) continue;
    const key = m[1];
    let val = m[2].trim();
    if (val.startsWith("[") && val.endsWith("]")) {
      val = val
        .slice(1, -1)
        .split(",")
        .map((s) => s.trim().replace(/^["']|["']$/g, ""))
        .filter(Boolean);
    } else {
      val = val.replace(/^["']|["']$/g, "");
    }
    meta[key] = val;
  }
  return { meta, body: match[2].trim() };
}

/** @param {string} rulesDir @returns {Promise<Rule[]>} */
export async function listRules(rulesDir) {
  let entries;
  try {
    entries = await readdir(rulesDir);
  } catch (err) {
    if (err.code === "ENOENT") return [];
    throw err;
  }
  const rules = [];
  for (const file of entries) {
    if (!file.endsWith(".md")) continue;
    const path = join(rulesDir, file);
    const st = await stat(path);
    if (!st.isFile()) continue;
    const src = await readFile(path, "utf8");
    const { meta } = parseFrontmatter(src);
    rules.push({
      name: meta.name || basename(file, ".md"),
      description: meta.description || "",
      globs: Array.isArray(meta.globs) ? meta.globs : meta.globs ? [meta.globs] : [],
      file,
    });
  }
  return rules;
}

/** @param {string} rulesDir @param {string} name @returns {Promise<Rule | null>} */
export async function getRule(rulesDir, name) {
  const rules = await listRules(rulesDir);
  const match = rules.find((r) => r.name === name);
  if (!match) return null;
  const src = await readFile(join(rulesDir, match.file), "utf8");
  const { body } = parseFrontmatter(src);
  return { ...match, body };
}
