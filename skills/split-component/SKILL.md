---
name: split-component
description: >
  Recursively splits React component into sub-components and hooks, writing all files.
  Use when user says "split this component", "component is too big", "break into components",
  or invokes /split-component [path]. Standalone.
---

# split-component

Recursive React component decomposition. Writes files. Stops when nothing left to extract.

## Process

1. **Infer conventions.** Scan 1–2 dirs up: folder structure, naming, barrel exports. Note `@components/<name>/index.ts` if present.
2. **Analyze target.** Extract candidates: large file, loop bodies, repeatable UI, distinct logical sections.
3. **Ask human** on ambiguous splits. One question at a time.
4. **Decide state boundary** per extraction: self-contained → move down; shared → props; complex/reusable logic → `hooks/use<Name>.ts`.
5. **Write** components to `@components/<Name>/index.ts`, hooks to `hooks/use<Name>.ts`.
6. **Rewrite** original importing new pieces.
7. **Recurse** on each child until stable.

## Output

```
Extracted:
- @components/UserList/index.ts — loop body
- @components/UserCard/index.ts — repeatable UI
- hooks/useUserFilters.ts — shared filter state
UserPage.tsx rewritten (312 → 48 lines)
```

## Anti-patterns

- Extract without judgment — check deletion test first
- >5 props when hook + context would reduce coupling
- Stop at first level when children still have candidates
