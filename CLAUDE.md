# ai — Skill Book

Plugin repo for Claude Code. Skills cover the full dev cycle: ticket intake → scope → slice → execute → refactor → ship → QA.

Published as `feature-dev@namadnuno`. Installed via `/plugin install feature-dev@namadnuno`.

## Purpose

Each skill is a reusable Claude instruction set. Skills auto-trigger from natural language or are invoked explicitly. They are not scripts — they are behavioral prompts that guide Claude through a specific workflow.

## Flow

```
ticket → grooming-it → grill-me → slice-it → [execute → review-it] × N → ship-it → qa-it
```

Standalone (invoke anytime): `grooming-it`, `qa-it`, `refactor-it`

## Skills

| Skill | Role in flow | Output |
|---|---|---|
| `grooming-it` | Pre-dev, ticket intake | Dev plan: user stories, tasks, edge cases |
| `grill-me` | Pre-dev, feature scoping | Build plan: scope, steps, files, test, deferred |
| `grill-agents` | Pre-agent-run, parallelisation | Spec files in `.agent.queue/pending/` |
| `slice-it` | Planning | Ordered vertical slices, each with a verify line |
| `review-it` | Post-slice | Blockers / Should-fix / Nits |
| `ship-it` | End of feature | Suite status, commit list, PR description |
| `qa-it` | Post-ship or anytime | Grouped human QA checklist from git diff vs main |
| `refactor-it` | Anytime | Slice-it compatible refactor plan from file analysis |
| `forge-init` | Project setup | `.agent.Dockerfile` + `.agent.md` for agent runs |
| `forge-rule` | Anytime | Persists current convention as `.agent/rules/<name>.md` for forge MCP |

## Skill anatomy

Every skill is a single `SKILL.md` at `skills/<name>/SKILL.md`.

```
skills/
  grill-me/SKILL.md
  slice-it/SKILL.md
  ...
```

### Frontmatter (required)

```yaml
---
name: skill-name
description: >
  One sentence what it does. Trigger phrases: "X", "Y", "Z".
  Used by Claude Code to decide when to auto-trigger.
---
```

Description is load-bearing — it controls auto-trigger. Write it to match the exact natural language the user will say, not a formal definition.

### Body conventions

- **H1** = skill name (matches `name` field)
- **H2 sections**: Input, Process, Output, Anti-patterns. Use only what's needed — don't pad.
- **Process** = numbered steps. Each step is an action, not a description.
- **Output** = exact format Claude should produce. Include a code block showing the shape.
- **Anti-patterns** = what to explicitly avoid. Keep short — 3–5 bullets max.
- No comments, no explanations of the obvious, no filler sections.

### Token discipline

Skills are loaded into context on every invocation. Every line costs tokens. Rules:
- No multi-paragraph sections
- No "this skill will help you..." intros
- Drop articles where reading is still clear
- 3–5 items per list, not exhaustive catalogs
- If a section has nothing to say, omit it

## Adding a skill

1. Create `skills/<name>/SKILL.md`
2. Write frontmatter with a trigger-phrase-rich description
3. Body: Input → Process → Output → Anti-patterns (omit empty sections)
4. Add row to `README.md` skills table
5. Update README header count and flow diagram if needed
6. Commit: `feat: add <name> skill`

## Skill design principles

- **One job.** If a skill does two things, it's two skills.
- **Output first.** Design the output format before writing the process. The process exists to produce the output.
- **Pair awareness.** Skills in this book pair with each other. `grill-me` → `slice-it` → `review-it` is a chain. New skills should state what they pair with or follow.
- **Standalone skills** explicitly say so in the description. They don't assume prior context from other skills.
- **Deviation from convention** is allowed but must be flagged. If a skill suggests going against repo patterns, it says so explicitly.

## Forge / agent conventions

Skills `forge-init` and `grill-agents` support running Claude Code as an agent in Docker:

- `.agent.Dockerfile` — container image for agent runs (Node 20+, git, non-root `agent` user, `WORKDIR /workspace`)
- `.agent.md` — conventions file loaded by agent at runtime (stack, commands, architecture, rules)
- `.agent.queue/pending/` — spec files written by `grill-agents`, one per agent task

`.agent.md` follows same token discipline as skills: no filler, concrete commands only, `# Architecture` section left for user.

## What not to add

- Skills that duplicate existing ones without clear differentiation
- Skills for one-off tasks that don't generalize
- Skills that are just "run this command" wrappers — use hooks or commands instead
- Type-specific variants (e.g. `refactor-component`) before the generic version is proven

<!-- forge:memory:start -->
## Forge memory (MCP `forge`)

This repo ships a memory MCP server. Use it to skip cold-start scans.

- **At session start**, call `repo_overview` once to get stack, entry points, key dirs, conventions.
- **Before editing files**, call `list_rules` (cheap — names + descriptions + globs only). If a rule's globs match the file you're about to touch, call `get_rule` to read the body.
- **Do not** bulk-grep the codebase to derive things `repo_overview` already states.

Rules live in `.agent/rules/`. Overview lives in `.agent/overview.md`. Edit directly or run `./.agent/analyze.sh` to scaffold.
<!-- forge:memory:end -->
