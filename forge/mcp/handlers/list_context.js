import { listContext } from "../indexer.js";

export class ListContextHandler {
  static schema = {
    name: "list_context",
    description:
      "List all saved knowledge base entries (scope + key only, no bodies). Cheap call — use to discover what's been learned, then call get_context to pull specific bodies.",
    inputSchema: {
      type: "object",
      properties: {},
      additionalProperties: false,
    },
  };

  /** @param {Ctx} ctx */
  constructor(ctx) {
    this.ctx = ctx;
  }

  /** @returns {ToolResult} */
  handle(_args) {
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
    const entries = listContext(this.ctx.db);
    if (entries.length === 0) {
      return { content: [{ type: "text", text: "(no context saved yet)" }] };
    }
    return {
      content: [{ type: "text", text: JSON.stringify(entries, null, 2) }],
    };
  }
}
