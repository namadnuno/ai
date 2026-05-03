---
name: refactor-it
description: Refactor a file and its dependencies — reads repo patterns first, identifies friction, outputs a slice-it compatible plan. Use when the user says "this file is too big", "refactor this", "split this component", "clean this up", or points at a specific file that needs restructuring.
---

# Refactor It

Read the file. Find the friction. Plan the fix using what the repo already does.

## Input

User points at a file. Accept: path, paste, or filename. If ambiguous, ask once.

## Process

### 1. Read the target

Read the file and its direct dependencies (imports it uses, files that directly use it). Build a picture of:
- What it does (responsibilities)
- How big it is (line count, export count)
- What it depends on

### 2. Find repo patterns

Before proposing anything, find 2–3 similar files in the repo (same type: component, usecase, controller, service). Use them as the baseline. Note:
- How they structure responsibilities
- How they split concerns
- Naming conventions
- What stays in one file vs what gets extracted

Narrate briefly: "Found `UserForm`, `OrderForm` as nearest components — both extract validation hooks and delegate list rendering to sub-components."

### 3. Identify friction

Apply these lenses. Only flag what's actually present:

- **Bloat** — file does more than one thing. Name the things.
- **Shallow extraction** — helper exists but caller is still complex. Deletion test: would inlining it simplify the caller? If yes, it's not earning its keep.
- **Leaky responsibility** — logic that belongs to another layer (e.g. formatting in a usecase, fetching in a component).
- **Duplication** — same shape exists elsewhere in the repo already.
- **Testability** — hard to test through current interface because too much is bundled.

Skip lenses with nothing to report.

### 4. Flag better patterns (when relevant)

If repo convention is the source of friction — say so plainly. One sentence. Offer the alternative and note it deviates from convention. User decides.

Example: "Repo pattern puts fetching in components, but this usecase would be cleaner with a dedicated data layer — deviates from convention."

## Output

Produce a refactor plan in slice-it format. Write to file (`refactor-plan.md`) if more than 4 slices.

```
## Refactor: [filename]

### Problems found
- [friction item]: [one line description]

### Plan

**Slice 1**: [goal]
- Files: [list]
- Change: [what moves/splits/merges]
- Verify: [how to know it's right]

**Slice 2**: ...

### Repo pattern used
[Which files were used as reference]

### Deviations from convention
[Any suggestions that go beyond current repo patterns — flagged explicitly]
```

## Token discipline

3–5 slices max. If more needed, the scope is too large — cut to the smallest version that removes the main friction, defer the rest explicitly.

One problem per slice. Slices that touch the same file can be merged.

## Anti-patterns

- Proposing rewrites when extraction suffices
- Extracting for the sake of it — apply deletion test first
- Ignoring repo patterns and inventing new ones without flagging
- Vague slices ("clean up the component") — name what moves where
- Refactoring tests alongside source in the same slice
