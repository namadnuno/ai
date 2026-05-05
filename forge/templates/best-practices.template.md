# Project conventions

> This file defines how agents should write code in **this** repository.
> Edit it to match your project. The agents read this on every run, before any code is written.
>
> Be specific. "Use clean code" is useless. "All API handlers go in `src/api/handlers/` and must export a default async function" is useful.

## Stack

<!-- Example:
- TypeScript 5, strict mode
- Next.js 15 with App Router
- Postgres via Drizzle ORM
- Tailwind CSS v4
-->

## Architecture rules

<!-- Example:
- Server Components by default; only use `"use client"` when interactivity is needed.
- Database access ONLY through `src/db/queries/` — never inline SQL or raw client calls in components or API routes.
- All external API calls go through `src/services/` with typed wrappers.
-->

## Code style

<!-- Example:
- Functional components only, no class components.
- Prefer `type` over `interface` unless declaration merging is needed.
- No default exports for utilities; default exports allowed only for React components and Next.js pages.
- Imports ordered: external, then `@/`, then relative.
-->

## Testing requirements

<!-- Example:
- Every new utility function in `src/lib/` needs a test in `tests/lib/`.
- Use Vitest. No Jest.
- Mock external services with `msw`. Never call real APIs in tests.
-->

## Commands the agent must run before finishing

<!-- These are critical — the agent will run them and not finish until they pass.
Example:
- `pnpm typecheck`
- `pnpm lint`
- `pnpm test --run`
-->

## Things to never do

<!-- Hard prohibitions. Be specific.
Example:
- Never edit files in `src/generated/` — they are generated from the Prisma schema.
- Never add a new dependency without checking with the team. Prefer using what's already in package.json.
- Never use `any` in TypeScript. If you truly need it, use `unknown` and narrow.
-->

## Commit messages

<!-- Example:
- Conventional commits: `feat(scope): ...`, `fix(scope): ...`, `refactor(scope): ...`
- Scope = feature area, e.g. `feat(auth): add password reset flow`
-->
