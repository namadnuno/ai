# ai — Feature-Building Skill Book

Four skills covering the full cycle of a small feature with an agent: **scope → slice → execute → ship**.

## Install

```
/plugins install github:namadnuno/ai
```

Run this on every machine. That's it.

## Skills

| Skill | Trigger | Output |
|---|---|---|
| `grill-me` | "I want to build X", "help me implement Y" | Build plan |
| `slice-it` | "slice this", "break into tasks", "make this agent-ready" | Ordered slice list |
| `review-it` | "review this", "check the code", "did the agent do this right" | Blockers / Should-fix / Nits |
| `ship-it` | "ship it", "wrap this up", "write the PR" | Test suite + commits + PR description |

Skills auto-trigger from natural language — no need to invoke by name. Force with `use grill-me` if auto-trigger misses.

## Flow

```
idea → grill-me → slice-it → [agent executes slice → review-it] × N → ship-it
```

## Update

```
/plugins update ai
```
