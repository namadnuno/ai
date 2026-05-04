---
name: slice-it
description: Break a scoped feature plan into vertical slices an agent can implement and verify one at a time. Use after grill-me, or when the user says "slice this," "break this into tasks," "plan the implementation," "make this agent-ready." Pairs with grill-me — grill-me decides what to build, slice-it decides how to hand it to an agent. Default to triggering whenever a build plan is on the table and execution is next.
---

# Slice It

Cut the plan into pieces an agent can execute without getting lost. Each slice ships observable behavior, verifies independently, leaves no decisions for the agent mid-flight.

## Prereq

No build plan? Stop and run grill-me. Slicing without one produces fiction.

## Rules

1. **Walking skeleton first.** Slice 1 is a thin end-to-end thread, stubs OK. Retires integration risk early.
2. **Vertical, not horizontal.** Each slice adds observable behavior. Never "first all DB, then all API, then all UI."
3. **Riskiest unknown first.** Find out in slice 2, not slice 8.
4. **Verify line is mandatory.** Test passes, curl returns X, button does Y. If you can't write it, the slice isn't sharp.
5. **No mid-slice decisions.** Library, naming, pattern — decide now or push back to grill-me.

## Template

```
## Slice N: [one-sentence goal]

Files: [best guess]
Steps:
  1. ...
Verify: [exact command or observable behavior]
Out of scope: [what NOT to touch]
```

## Sizing

- Too big: agent needs >~5 files in context. Split.
- Too small: no observable behavior added. Bundle into a slice that needs it.
- Ballpark: 2-6 slices. 10+ means go back to grill-me.

## Anti-patterns

- Horizontal layers — nothing ships until everything's done.
- Hidden dependencies — slice 3 secretly uses slice 1's helper. Make explicit or merge.
- "Refactor" as its own slice unless the refactor *is* the goal.
- Vague verify lines. "Works correctly" is not a verify line.
- Slicing work the user grilled away.

## Output

Restructured plan as ordered slices. Lead with one paragraph: why this order, what risk each slice retires, where first user-visible value lands. Each slice fills the template — agent executes slice N without re-reading the conversation.

**Always write output to `PLAN.md`** in the project root. Overwrite if exists.
