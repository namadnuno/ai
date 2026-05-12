import { syncIndex, searchContent as queryContent } from "../indexer.js";

export class SearchContentHandler {
  static schema = {
    name: "search_content",
    description:
      "Full-text search across indexed repo file contents. Returns ranked results with excerpts. Respects .gitignore. Supports FTS5 syntax: bare words, quoted phrases, field:value.",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "FTS5 query string" },
        limit: { type: "number", description: "Max results (default 20)" },
      },
      required: ["query"],
      additionalProperties: false,
    },
  };

  /** @param {Ctx} ctx */
  constructor(ctx) {
    this.ctx = ctx;
  }

  /** @param {SearchContentArgs} args @returns {ToolResult} */
  handle(args) {
    if (!this.ctx.db) {
      return {
        content: [
          {
            type: "text",
            text: "error: index unavailable (run npm install in .agent/mcp)",
          },
        ],
        isError: true,
      };
    }
    if (!args.query) {
      return {
        content: [{ type: "text", text: "error: query required" }],
        isError: true,
      };
    }
    syncIndex(this.ctx.ROOT, this.ctx.db);
    const results = queryContent(this.ctx.db, args.query, args.limit ?? 20);
    return {
      content: [{ type: "text", text: JSON.stringify(results, null, 2) }],
    };
  }
}
