import { listRules } from "../utils.js";

export class ListRulesHandler {
  static schema = {
    name: "list_rules",
    description:
      "Lists all project rules with name, description, and matching globs. Cheap call — use to decide which rules to pull. Pull a rule body via get_rule before editing files matching its globs.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
  };

  /** @param {Ctx} ctx */
  constructor(ctx) {
    this.ctx = ctx;
  }

  /** @returns {Promise<ToolResult>} */
  async handle(_args) {
    const rules = await listRules(this.ctx.RULES_DIR);
    const summary = rules.map(({ name, description, globs }) => ({ name, description, globs }));
    return { content: [{ type: "text", text: JSON.stringify(summary, null, 2) }] };
  }
}
