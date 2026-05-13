#!/usr/bin/env node
// Forge memory MCP server — stdio.
// Reads from .agent/overview.md and .agent/rules/ relative to cwd.

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { resolve } from "node:path";
import { openDb } from "./indexer.js";
import { RepoOverviewHandler } from "./handlers/repo_overview.js";
import { ListRulesHandler } from "./handlers/list_rules.js";
import { GetRuleHandler } from "./handlers/get_rule.js";
import { SearchFilesHandler } from "./handlers/search_files.js";
import { SearchContentHandler } from "./handlers/search_content.js";
import { SaveContextHandler } from "./handlers/save_context.js";
import { ListContextHandler } from "./handlers/list_context.js";
import { GetContextHandler } from "./handlers/get_context.js";
import { PreEditHandler } from "./handlers/pre_edit.js";

const ROOT = process.env.FORGE_ROOT || process.cwd();

let db = null;
try {
  db = openDb(ROOT);
} catch (err) {
  process.stderr.write(`forge-mcp: index unavailable — ${err.message}\n`);
}

const ctx = {
  db,
  ROOT,
  OVERVIEW_PATH: resolve(ROOT, ".agent/overview.md"),
  RULES_DIR: resolve(ROOT, ".agent/rules"),
};

/** @type {HandlerClass[]} */
const HANDLER_CLASSES = [
  RepoOverviewHandler,
  ListRulesHandler,
  GetRuleHandler,
  SearchFilesHandler,
  SearchContentHandler,
  SaveContextHandler,
  ListContextHandler,
  GetContextHandler,
  PreEditHandler,
];

const handlers = Object.fromEntries(HANDLER_CLASSES.map((H) => [H.schema.name, new H(ctx)]));

const server = new Server({ name: "forge", version: "0.1.0" }, { capabilities: { tools: {} } });

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: HANDLER_CLASSES.map((H) => H.schema),
}));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const { name, arguments: args = {} } = req.params;
  const handler = handlers[name];
  if (!handler) {
    return { content: [{ type: "text", text: `unknown tool: ${name}` }], isError: true };
  }
  return handler.handle(args);
});

const transport = new StdioServerTransport();
await server.connect(transport);
