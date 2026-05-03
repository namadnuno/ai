---
name: write-skill
description: Create a new skill for this repo following its conventions — frontmatter, body structure, token discipline, README update. Use when the user says "write a skill", "create a skill", "add a skill", "new skill for X", or invokes /write-skill.
---

# Write Skill

Build a new skill that fits this book's conventions. Output = ready-to-commit files.

## Process

1. **Clarify** (if not already clear from context):
   - What does it do? One sentence.
   - What triggers it? Exact phrases the user will say.
   - What does it output?
   - Standalone or pairs with another skill?

2. **Check for overlap.** Grep `skills/*/SKILL.md` descriptions. If a skill already covers this, say so before creating a duplicate.

3. **Draft `skills/<name>/SKILL.md`** following the structure below.

4. **Update `README.md`** — add row to skills table, update count in header if needed, update flow diagram if skill has a fixed position.

5. **Show both files.** Ask for confirmation before writing.

## SKILL.md structure

```markdown
---
name: <name>
description: <what it does>. Use when user says "<trigger 1>", "<trigger 2>", or invokes /<name>.
---

# Title

One-line orientation sentence. What problem this solves.

## Input (omit if obvious)

## Process

Numbered steps. Each step = an action.

## Output

Exact format. Include a code block showing the shape.

## Anti-patterns (omit if none)

- What to explicitly avoid
```

## Conventions

- Description triggers must match natural language the user actually says — not formal definitions.
- Process steps are actions, not descriptions. "Read the diff" not "The diff is read."
- Output section always includes the format shape — never leave it vague.
- Omit sections that have nothing to say. Empty sections waste tokens.
- 3–5 bullets per list. Not exhaustive.
- No intro sentences ("This skill will help you..."). Start with substance.

## Placement in flow

State explicitly in description if standalone. If it pairs with another skill, name it:
- "Pairs with `grill-me`" or "Use after `slice-it`"
- Standalone skills: "invoke anytime, independent of dev flow"

## Done when

- `skills/<name>/SKILL.md` written
- README skills table updated
- README header count correct
- Flow diagram updated if skill has a fixed position
