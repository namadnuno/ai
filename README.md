# ai — Feature-Building Skill Book

Eleven skills covering the full cycle from ticket intake to QA: **groom → scope → slice → execute → refactor → ship → test**.

## Install

```
/plugin marketplace add namadnuno/ai
/plugin install feature-dev@namadnuno
```

If SSH isn't configured for GitHub, use HTTPS instead:

```
/plugin marketplace add https://github.com/namadnuno/ai.git
/plugin install feature-dev@namadnuno
```

Run these on every machine. That's it. To update:

```
/plugin marketplace update namadnuno
```

## Skills

| Skill | Trigger | Output |
|---|---|---|
| `grooming-it` | "groom this ticket", Jira URL, pasted spec | Dev plan doc (user stories, task breakdown, edge cases) |
| `grill-me` | "I want to build X", "help me implement Y" | Build plan |
| `slice-it` | "slice this", "break into tasks", "make this agent-ready" | Ordered slice list |
| `review-it` | "review this", "check the code", "did the agent do this right" | Blockers / Should-fix / Nits |
| `ship-it` | "ship it", "wrap this up", "write the PR" | Test suite + commits + PR description |
| `qa-it` | "qa this", "what should I test", "qa checklist" | Grouped human QA checklist from git diff |
| `refactor-it` | "this file is too big", "refactor this", "split this component" | Slice-it compatible refactor plan |
| `write-skill` | "write a skill", "create a skill", "add a skill for X" | Ready-to-commit SKILL.md + README update |
| `missing-it` | "what am I missing", "what's not covered", "am I forgetting anything" | Prioritized gaps list: tests, edge cases, error paths |
| `tdd` | "use TDD", "test-first", "red-green-refactor", "write tests before code" | Red→green→refactor loop with behavior checklist |

Skills auto-trigger from natural language — no need to invoke by name. Force with `use grill-me` if auto-trigger misses.

## Flow

```
ticket → grooming-it → grill-me → slice-it → [agent executes slice → review-it] × N → ship-it → qa-it
```

`grooming-it`, `qa-it`, and `refactor-it` are standalone — invoke anytime, independent of the main flow.
