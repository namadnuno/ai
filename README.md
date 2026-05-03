# ai — Feature-Building Skill Book

Six skills covering the full cycle from ticket intake to QA: **groom → scope → slice → execute → ship → test**.

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

Skills auto-trigger from natural language — no need to invoke by name. Force with `use grill-me` if auto-trigger misses.

## Flow

```
ticket → grooming-it → grill-me → slice-it → [agent executes slice → review-it] × N → ship-it → qa-it
```

`grooming-it` and `qa-it` are standalone — invoke anytime, independent of the main flow.
