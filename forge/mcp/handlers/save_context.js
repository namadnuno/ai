import { saveContext } from "../indexer.js";

export class SaveContextHandler {
  static schema = {
    name: "save_context",
    description:
      "Persist an insight about a file or the project into the forge knowledge base. Use after understanding something non-obvious: architecture decisions, gotchas, patterns, module purpose. Survives across sessions. Keep body to 1-3 sentences.",
    inputSchema: {
      type: "object",
      properties: {
        scope: {
          type: "string",
          description:
            "File path (e.g. src/auth/middleware.ts) or '__project__' for repo-level insight",
        },
        key: {
          type: "string",
          description: "Category: overview | patterns | gotchas | why | deps",
        },
        body: {
          type: "string",
          description: "The insight. 1-3 sentences max. Non-obvious only.",
        },
      },
      required: ["scope", "key", "body"],
      additionalProperties: false,
    },
  };

  /** @param {Ctx} ctx */
  constructor(ctx) {
    this.ctx = ctx;
  }

  /** @param {SaveContextArgs} args @returns {ToolResult} */
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
    const { scope, key, body } = args;
    if (!scope || !key || !body) {
      return {
        content: [{ type: "text", text: "error: scope, key, and body required" }],
        isError: true,
      };
    }
    saveContext(this.ctx.db, scope, key, body);
    return { content: [{ type: "text", text: `saved: ${scope} / ${key}` }] };
  }
}
