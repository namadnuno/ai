---
name: review-it
description: Review code an agent just generated — run automated checks (tests, type check, lint, build), then review for scope drift, pattern consistency, and common code-gen failure modes. Use after slice-it execution, or when the user says "review this," "check the code," "did the agent do this right," "lint and fix." Pairs with grill-me and slice-it — closes the scope → execute → verify loop. Default to triggering whenever code has just been generated.
---

# Review It

Strict reviewer mindset. Pass = automated checks green AND zero blockers.

## Order

1. **Run automated checks first.** Tests, type check, lint, build. Anything red → stop, fix those before reviewing further.
2. **Diff against the slice.** Files actually touched vs the slice's `Files:` list. Anything outside is scope drift.
3. **Run the verify line.** The slice's `Verify:` must be green.
4. **Pattern check.** For each new function/file, find the closest existing equivalent. Did the agent match the project's pattern or invent one?
5. **Walk the lenses below.**

## Lenses

- **Dead artifacts** — unused imports, dead code, `console.log`, debug prints, commented-out blocks, orphan TODOs. Delete.
- **Defensive noise** — try/catch that swallows, null checks on things that can't be null, retries with no recovery path. Remove or justify.
- **Comment hygiene** — comments that say *what* (delete) vs *why* (keep). No "// increment counter."
- **Unearned abstractions** — helpers used once. Inline.
- **Test quality** — tests assert observable behavior, not implementation. Snapshot tests on logic = anti-signal.
- **Error handling** — fail loud at boundaries; catch only where there's real recovery.
- **Naming consistency** — match the file's existing conventions, don't invent new ones.

## Anti-patterns

- New file when an existing one would do.
- Re-implementing something the codebase already has (grep before flagging — agents often miss helpers).
- "While I was here" refactors not in the slice.
- Tests that pass by mirroring the implementation.
- `as any`, `!`, or type assertions papering over real errors.

## Output

Three buckets:

- **Blockers** — checks failing, scope drift, broken verify line. Zero before merge.
- **Should fix** — pattern breaks, dead code, weak tests. Address before merge.
- **Nits** — naming, comments, ordering. Optional.

Format each finding: `file:line — what's wrong — suggested fix`. End with check status: tests ✓/✗, typecheck ✓/✗, lint ✓/✗, build ✓/✗.
