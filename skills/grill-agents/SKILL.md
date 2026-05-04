---
name: grill-agents
description: Break a feature, feedback doc, or task list into isolated agent specs, write each to .agent.queue/pending/ for parallel execution. Use when the user says "queue this for agents", "split this for subagents", "grill agents", "create agent specs", or has a list of tasks to parallelize. Pairs with .agent/start.sh and .agent/review.sh.
---

# Grill Agents

Split work into isolated specs. Each spec = one agent run, one branch, one concern.

## Input

Accept any of: feature description, feedback document, task list, or conversation context. If none, ask for it.

## Process

1. **Read input.** Identify distinct tasks — each must be implementable without knowledge of sibling tasks' internals.
2. **Find dependencies.** If task B needs task A's output (schema, interface, file), mark `depends_on: spec-NNN`. Default: no deps. Prefer independence.
3. **Size check.** Each spec: ≤5 files, single concern. Too big → split. Too small → bundle.
4. **Write spec files** to `.agent.queue/pending/`. Filename = `<id>.md`. Overwrite if exists.
5. **Show summary** — list of specs queued, dep tree if any.

## Spec format

```markdown
---
id: spec-NNN
title: One sentence, what the agent implements
depends_on: spec-001, spec-002
branch: feature/spec-NNN
---

# Task

[Concrete description: what to build, which files, expected behavior.]
[Include edge cases and constraints the agent must respect.]
[Do NOT include implementation details — agent decides how.]

## Acceptance criteria

- [ ] [observable behavior, not code]
- [ ] ...
```

- `id`: sequential, `spec-001` format
- `depends_on`: comma-separated ids, or empty
- `branch`: `feature/<id>` by default

## Anti-patterns

- Specs that share mutable state without a dep — race condition
- Specs so small they're one-liners — bundle
- Specs that require reading another spec's code mid-run — restructure or add dep
- More than ~8 specs without clear rationale — probably needs grill-me first

## Output

After writing files:

```
Queued N specs to .agent.queue/pending/

  spec-001  Title here              (no deps)
  spec-002  Title here              (no deps)
  spec-003  Title here              (depends on spec-001)

Run .agent/start.sh to execute.
```
