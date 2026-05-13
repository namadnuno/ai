import { minimatch } from "minimatch";
import { listRules, getRule } from "../utils.js";
import { getContext } from "../indexer.js";

export class PreEditHandler {
  static schema = {
    name: "pre_edit",
    description:
      "Call before editing a file. Returns all matching rules (mandatory conventions) AND all saved context insights for that path — everything needed before touching the file, in one call.",
    inputSchema: {
      type: "object",
      properties: {
        path: {
          type: "string",
          description: "File path relative to repo root (e.g. src/components/Foo.tsx)",
        },
      },
      required: ["path"],
      additionalProperties: false,
    },
  };

  /** @param {Ctx} ctx */
  constructor(ctx) {
    this.ctx = ctx;
  }

  /** @param {PreEditArgs} args @returns {Promise<ToolResult>} */
  async handle(args) {
    if (!args.path) {
      return { content: [{ type: "text", text: "error: path required" }], isError: true };
    }
    const { RULES_DIR, db } = this.ctx;
    const sections = [];

    const rules = await listRules(RULES_DIR);
    const matching = rules.filter(
      (r) =>
        r.globs.length > 0 && r.globs.some((g) => minimatch(args.path, g, { matchBase: false })),
    );
    if (matching.length > 0) {
      const parts = await Promise.all(
        matching.map(async (r) => {
          const full = await getRule(RULES_DIR, r.name);
          const head = `# rule: ${r.name}\n\n${r.description}\n\nGlobs: ${r.globs.join(", ")}\n\n---\n\n`;
          return head + (full?.body ?? "");
        }),
      );
      sections.push(`## Rules\n\n${parts.join("\n\n---\n\n")}`);
    }

    if (db) {
      const ctx = getContext(db, args.path);
      if (ctx.length > 0) {
        const ctxText = ctx.map((e) => `**${e.key}**: ${e.body}`).join("\n");
        sections.push(`## Saved context\n\n${ctxText}`);
      }
    }

    if (sections.length === 0) {
      return { content: [{ type: "text", text: "(no rules or saved context for this path)" }] };
    }
    return { content: [{ type: "text", text: sections.join("\n\n---\n\n") }] };
  }
}
