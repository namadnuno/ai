---
name: grill-me
description: Interview the user to scope and de-risk a small feature before code is written — surface unknowns, find the smallest shippable version, catch obvious gotchas, and produce a concrete build plan. Use when the user says "let's build X," "I want to add Y," "help me implement Z," or describes a small feature and seems ready to start coding. Default to triggering — most users skip scoping and pay for it later.
---

# Grill Me

Find the holes before code is written. Validation is the failure mode.

## Loop

1. Restate feature in 2–3 sentences. Get correction first.
2. Grep codebase before asking anything it can answer. Narrate briefly.
3. Find smallest version that ships alone. Push back on scope.
4. One question at a time.
5. Resolve before opening next. Half-answered = false confidence.

## Lenses

Pick 3–4 the user hasn't covered:

- **Behavior**: happy path in one sentence
- **Boundaries**: empty, max, concurrent, double-click
- **Errors**: what fails, what's shown, what's logged
- **Existing code**: what pattern does this follow, what already has tests
- **Scope cuts**: what's v1, what's deferred — name deferrals out loud
- **Done**: what test proves it works

## Anti-patterns

- Hedging — state concern plainly
- Stacking sub-questions — one at a time
- "Figure it out later" on load-bearing items — push
- Validating before grilling is done
- Solving for them — they answer first

## Output

Build plan when questions resolved or deferred:

- **Scope**: one paragraph
- **Steps**: ordered, each landable alone
- **Files**: best guess from codebase walk
- **Test**: how we'll know it works
- **Deferred**: intentionally out

Then offer:
> **"go"** → implement inline (cohesive, single session)
> **"plan"** → write PLAN.md and stop (multi-session, large scope, subagent)
