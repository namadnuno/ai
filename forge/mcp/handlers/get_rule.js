import { getRule } from "../utils.js";

export class GetRuleHandler {
  static schema = {
    name: "get_rule",
    description:
      "Returns the full body of a rule by name. Call before editing files matching the rule's globs.",
    inputSchema: {
      type: "object",
      properties: { name: { type: "string" } },
      required: ["name"],
      additionalProperties: false,
    },
  };

  /** @param {Ctx} ctx */
  constructor(ctx) {
    this.ctx = ctx;
  }

  /** @param {GetRuleArgs} args @returns {Promise<ToolResult>} */
  async handle(args) {
    if (!args.name) {
      return { content: [{ type: "text", text: "error: name required" }], isError: true };
    }
    const rule = await getRule(this.ctx.RULES_DIR, args.name);
    if (!rule) {
      return {
        content: [{ type: "text", text: `error: rule '${args.name}' not found` }],
        isError: true,
      };
    }
    const head = `# ${rule.name}\n\n${rule.description}\n\nGlobs: ${rule.globs.join(", ") || "(none)"}\n\n---\n\n`;
    return { content: [{ type: "text", text: head + rule.body }] };
  }
}
