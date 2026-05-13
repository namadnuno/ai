import { getContext } from "../indexer.js";

export class GetContextHandler {
  static schema = {
    name: "get_context",
    description:
      "Retrieve saved insights from the forge knowledge base. Pass scope to get entries for a specific file or '__project__'. Omit scope to get everything (use sparingly — prefer list_context first).",
    inputSchema: {
      type: "object",
      properties: {
        scope: {
          type: "string",
          description: "File path or '__project__'. Omit for all entries.",
        },
      },
      additionalProperties: false,
    },
  };

  /** @param {Ctx} ctx */
  constructor(ctx) {
    this.ctx = ctx;
  }

  /** @param {GetContextArgs} args @returns {ToolResult} */
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
    const entries = getContext(this.ctx.db, args.scope);
    if (entries.length === 0) {
      return {
        content: [{ type: "text", text: "(no context saved for this scope)" }],
      };
    }
    return {
      content: [{ type: "text", text: JSON.stringify(entries, null, 2) }],
    };
  }
}
