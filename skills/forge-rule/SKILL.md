---
name: forge-rule
description: >
  Capture a project rule mid-session into .agent/rules/<name>.md so the forge MCP server exposes it to future Claude sessions.
  Use when user says "save this as a rule", "add a forge rule", "remember this convention", "/forge-rule".
  Standalone — pairs with forge memory MCP.
---

# Forge Rule

Persist a decision or convention as a queryable rule for future sessions.

## Input

- The convention/decision to capture (from current session context — recent user instruction, agreed pattern, or fix-the-pattern moment)
- Optional: rule name and globs from user

## Process

1. Verify `.agent/rules/` exists. If not, tell user to run `./.agent/analyze.sh` first.
2. Pick a short kebab-case `name` from the convention (e.g. `db-queries`, `error-logging`). Confirm with user if ambiguous.
3. Pick `globs` — paths the rule applies to. Ask if not obvious. `["**/*"]` only if truly universal.
4. Write one-sentence `description` — must be self-explanatory in `list_rules` output so future Claude can decide whether to pull body.
5. Write body: why the rule exists, one correct example, one anti-pattern. Keep concrete.
6. Write file to `.agent/rules/<name>.md` with frontmatter. Refuse to overwrite existing rule without confirmation.
7. Confirm: name, path, globs.

## Output

```markdown
---
name: <kebab-name>
description: <one sentence>
globs: ["<glob>", ...]
---

# <Title>

Why: <reason>

Correct:
\`\`\`
<example>
\`\`\`

Anti-pattern:
\`\`\`
<bad example>
\`\`\`
```

Confirm to user:

```
Saved → .agent/rules/<name>.md
Globs: <list>
Future Claude sessions will see it via list_rules.
```

## Anti-patterns

- Vague descriptions ("be careful with X") — must be concrete enough that Claude can pull body without reading first
- Universal globs unless rule truly applies everywhere
- Long bodies — keep under 30 lines, link to source files for detail
- Overwriting existing rule without confirm
