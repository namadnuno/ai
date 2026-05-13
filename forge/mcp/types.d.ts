interface Ctx {
  db: import("better-sqlite3").Database | null;
  ROOT: string;
  OVERVIEW_PATH: string;
  RULES_DIR: string;
}

interface ToolContent {
  type: "text";
  text: string;
}

interface ToolResult {
  content: ToolContent[];
  isError?: boolean;
}

interface ToolSchema {
  name: string;
  description: string;
  inputSchema: Record<string, unknown>;
}

interface Handler {
  handle(args: Record<string, unknown>): ToolResult | Promise<ToolResult>;
}

interface HandlerClass {
  new (ctx: Ctx): Handler;
  schema: ToolSchema;
}

interface Rule {
  name: string;
  description: string;
  globs: string[];
  file: string;
  body?: string;
}

interface ContextEntry {
  scope?: string;
  key: string;
  body: string;
  updated: number;
}

interface SearchResult {
  path: string;
  excerpt: string;
  rank: number;
}

interface FrontmatterResult {
  meta: Record<string, string | string[]>;
  body: string;
}

interface SyncStats {
  indexed: number;
  skipped: number;
  deleted: number;
  cached?: boolean;
}

interface ContextSummary {
  scope: string;
  key: string;
  updated: number;
}
