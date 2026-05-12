import { minimatch } from "minimatch";
import { syncIndex, getAllPaths } from "../indexer.js";

export class SearchFilesHandler {
  static schema = {
    name: "search_files",
    description:
      "Search indexed repo files by glob pattern. Respects .gitignore. Returns matching file paths. Use instead of filesystem grepping.",
    inputSchema: {
      type: "object",
      properties: {
        pattern: {
          type: "string",
          description: "Glob pattern, e.g. src/**/*.ts",
        },
      },
      required: ["pattern"],
      additionalProperties: false,
    },
  };

  /** @param {Ctx} ctx */
  constructor(ctx) {
    this.ctx = ctx;
  }

  /** @param {SearchFilesArgs} args @returns {ToolResult} */
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
    if (!args.pattern) {
      return {
        content: [{ type: "text", text: "error: pattern required" }],
        isError: true,
      };
    }
    syncIndex(this.ctx.ROOT, this.ctx.db);
    const matches = getAllPaths(this.ctx.db).filter((p) =>
      minimatch(p, args.pattern, { matchBase: false }),
    );
    return { content: [{ type: "text", text: JSON.stringify(matches) }] };
  }
}
