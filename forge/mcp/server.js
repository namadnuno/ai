#!/usr/bin/env node
// Forge memory MCP server — stdio.
// Exposes repo overview + user-authored rules to Claude sessions.
// Reads from .agent/overview.md and .agent/rules/*.md relative to cwd.

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { readFile, readdir, stat } from "node:fs/promises";
import { join, basename, resolve } from "node:path";

const ROOT = process.env.FORGE_ROOT || process.cwd();
const OVERVIEW_PATH = resolve(ROOT, ".agent/overview.md");
const RULES_DIR = resolve(ROOT, ".agent/rules");

async function readIfExists(path) {
  try {
    return await readFile(path, "utf8");
  } catch (err) {
    if (err.code === "ENOENT") return null;
    throw err;
  }
}

function parseFrontmatter(src) {
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

async function listRules() {
  let entries;
  try {
    entries = await readdir(RULES_DIR);
  } catch (err) {
    if (err.code === "ENOENT") return [];
    throw err;
  }
  const rules = [];
  for (const file of entries) {
    if (!file.endsWith(".md")) continue;
    const path = join(RULES_DIR, file);
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

async function getRule(name) {
  const rules = await listRules();
  const match = rules.find((r) => r.name === name);
  if (!match) return null;
  const src = await readFile(join(RULES_DIR, match.file), "utf8");
  const { body } = parseFrontmatter(src);
  return { ...match, body };
}

const server = new Server(
  { name: "forge", version: "0.1.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "repo_overview",
      description:
        "Returns the repo's curated overview (stack, entry points, key dirs, conventions). Call this once at session start before exploring the codebase.",
      inputSchema: { type: "object", properties: {}, additionalProperties: false },
    },
    {
      name: "list_rules",
      description:
        "Lists all project rules with name, description, and matching globs. Cheap call — use to decide which rules to pull. Pull a rule body via get_rule before editing files matching its globs.",
      inputSchema: { type: "object", properties: {}, additionalProperties: false },
    },
    {
      name: "get_rule",
      description:
        "Returns the full body of a rule by name. Call before editing files matching the rule's globs.",
      inputSchema: {
        type: "object",
        properties: { name: { type: "string" } },
        required: ["name"],
        additionalProperties: false,
      },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const { name, arguments: args = {} } = req.params;

  if (name === "repo_overview") {
    const content = await readIfExists(OVERVIEW_PATH);
    if (content === null) {
      return {
        content: [
          {
            type: "text",
            text: "(no overview yet — create .agent/overview.md or run ./.agent/analyze.sh)",
          },
        ],
      };
    }
    return { content: [{ type: "text", text: content }] };
  }

  if (name === "list_rules") {
    const rules = await listRules();
    const summary = rules.map(({ name, description, globs }) => ({ name, description, globs }));
    return { content: [{ type: "text", text: JSON.stringify(summary, null, 2) }] };
  }

  if (name === "get_rule") {
    if (!args.name) {
      return { content: [{ type: "text", text: "error: name required" }], isError: true };
    }
    const rule = await getRule(args.name);
    if (!rule) {
      return { content: [{ type: "text", text: `error: rule '${args.name}' not found` }], isError: true };
    }
    const head = `# ${rule.name}\n\n${rule.description}\n\nGlobs: ${rule.globs.join(", ") || "(none)"}\n\n---\n\n`;
    return { content: [{ type: "text", text: head + rule.body }] };
  }

  return { content: [{ type: "text", text: `unknown tool: ${name}` }], isError: true };
});

const transport = new StdioServerTransport();
await server.connect(transport);
