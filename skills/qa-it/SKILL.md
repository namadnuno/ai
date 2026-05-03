---
name: qa-it
description: Generate a human QA checklist from git diff vs main — grouped by feature area inferred from changed code. Use when the user says "qa this", "what should I test", "qa checklist", "test this feature", or invokes /qa-it. Standalone — invoke anytime, independent of dev flow.
---

# QA It

Read the diff. Infer what changed. Tell the human what to test.

## Input

Run `git diff main` (or `git diff origin/main` if needed). If no diff, use staged changes (`git diff --staged`). If neither, use conversation context.

## Process

1. **Read the diff.** Identify changed files, functions, and behaviors.
2. **Infer feature areas.** Group by logical feature, not by file. One file touching auth + UI = two groups.
3. **Per area, generate checklist items.** Cover: happy path, edge cases, error states, regressions on adjacent behavior.
4. **Cut noise.** No items that test language/framework behavior. Only items that test *this* change.

## Output format

```
## [Feature Area]
- [ ] [what to do] → [expected result]
- [ ] [what to do] → [expected result]

## [Feature Area 2]
- [ ] ...
```

One line per item. Action + expected result. No explanations. No "verify that" — start with verb.

## Lenses per area

- **Happy path** — does the main flow work end to end?
- **Edge cases** — empty input, max input, invalid input, concurrent action
- **Error states** — what breaks? Is the error message correct? Does it recover?
- **Regressions** — what adjacent feature could this diff have broken?
- **UI/UX** (if frontend changed) — loading state, disabled state, mobile, keyboard nav

## Anti-patterns

- Items that are always true ("page loads") — skip unless the diff touches loading
- Vague items ("test the form") — be specific about which field and what value
- Testing framework internals — only observable behavior
- More than ~5 items per area — if the area is too broad, split it

## Token discipline

Fewer, sharper items beat long lists. If two items test the same behavior from different angles, pick one. Default: 3–5 items per area.
