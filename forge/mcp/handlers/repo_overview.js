import { readIfExists } from "../utils.js";

export class RepoOverviewHandler {
  static schema = {
    name: "repo_overview",
    description:
      "Returns the repo's curated overview (stack, entry points, key dirs, conventions). Call this once at session start before exploring the codebase.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
  };

  /** @param {Ctx} ctx */
  constructor(ctx) {
    this.ctx = ctx;
  }

  /** @returns {Promise<ToolResult>} */
  async handle(_args) {
    const content = await readIfExists(this.ctx.OVERVIEW_PATH);
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
}
