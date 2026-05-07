---
name: split-function
description: >
  Recursively splits a function or hook into smaller focused functions and hooks, writing all changes.
  Use when user says "split this function", "this hook is too big", "break this function up",
  or invokes /split-function [path] [functionName]. Standalone.
---

# split-function

Recursive function/hook decomposition. Writes changes in place. Stops when nothing left to extract.

## Input

- File path (required)
- Function or hook name (required)

## Process

1. **Infer conventions.** Scan 1–2 dirs up: utils location, hook naming, barrel exports.
2. **Analyze target function.** Extract candidates: large body, nested functions, repeated logic, complex conditionals, distinct responsibilities.
3. **For hooks:** also flag — multiple `useEffect` concerns, state groups that move together, derived state extractable to sub-hook.
4. **Ask human** on ambiguous splits. One question at a time.
5. **Decide placement** per extraction:
   - Pure logic → same file or `utils/<name>.ts`
   - Reusable across files → dedicated `utils/` or `lib/` module
   - Hook logic → `hooks/use<Name>.ts`
6. **Write** extracted functions/hooks to correct locations.
7. **Rewrite** original importing new pieces.
8. **Recurse** on each extracted piece until stable.

## Output

```
Extracted:
- hooks/useFormValidation.ts — validation state + handlers
- hooks/useSubmitHandler.ts — submit side effects
- utils/formatPayload.ts — pure data transform
useCheckoutForm.ts rewritten (198 → 42 lines)
```

## Anti-patterns

- Extract without purpose — name what responsibility moves where
- Micro-functions under 3 lines unless reused elsewhere
- Splitting hooks without checking if single `useReducer` would be cleaner
- Stop at first level when extracted pieces still have candidates
