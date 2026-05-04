---
name: forge-init
description: Generate .agent.Dockerfile and .agent.md for the current project by detecting its stack. Use when the user says "init forge", "setup forge", "generate dockerfile for agents", "forge init", or just installed forge into a project. Standalone.
---

# Forge Init

Detect stack, write `.agent.Dockerfile` and `.agent.md`. Skip files that already exist unless user confirms overwrite.

## Monorepo detection (run first)

Check repo root for: `pnpm-workspace.yaml`, `turbo.json`, `nx.json`, `lerna.json`, `rush.json`.

If found → monorepo mode:
1. List apps/packages dirs (from workspace config or `apps/`, `packages/`, `services/` conventions)
2. Ask: "Which app? (or 'all' to init each)" 
3. For each target app: `cd <app>`, run normal stack detection, write `.agent.Dockerfile` and `.agent.md` **inside that app dir**
4. In `.agent.md`, add a **Monorepo** section:
   - `workspace root`: path to repo root relative to this app
   - `shared packages`: list any `packages/*` this app imports (grep `package.json` deps)
   - `scope rule`: "Only modify files under `<app-path>/` and `packages/<shared>` this app depends on"

The `.agent/` folder still installs at the app level. Agent mounts full monorepo as `/workspace` (via `git rev-parse --show-toplevel`) so shared packages are readable — `.agent.md` scopes what it may write.

## Process

1. **Detect monorepo** (see above). If monorepo, resolve target app first.
2. **Detect stack** — scan app dir for these signals, in order:

| Signal | Stack |
|---|---|
| `package.json` | Node/TS/JS — check `engines.node`, infer pnpm/yarn/npm from lockfile |
| `requirements.txt` / `pyproject.toml` / `uv.lock` | Python — check version from `.python-version` or pyproject |
| `go.mod` | Go |
| `Cargo.toml` | Rust |
| `*.csproj` / `*.sln` | .NET |
| `mix.exs` | Elixir |
| `build.gradle` / `pom.xml` | Java/Kotlin |
| `Gemfile` | Ruby |
| `shell.nix` / `flake.nix` | Nix shell |
| Only shell scripts / `Makefile` | Bare shell |

Multiple signals = multi-stack (e.g. Python API + Node frontend). List all layers.

2. **Read package manager** — lockfile wins: `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, else npm.

3. **Read test/lint commands** — check `package.json` scripts, `Makefile` targets, `pyproject.toml [tool.pytest]`, etc. Extract actual commands.

4. **Write `.agent.Dockerfile`** — use correct base image, install Node separately if needed for Claude CLI, install project tools. Must satisfy requirements:
   - Node 20+ (for Claude Code CLI)
   - `git`, `curl`, `jq`, `bash`
   - non-root user `agent` with home `/home/agent`
   - `WORKDIR /workspace`

5. **Write `.agent.md`** — populate with detected: stack, package manager, test command, lint command, build command, key directories. Leave `# Architecture` section for user to fill.

## .agent.Dockerfile patterns by stack

**Node (npm/yarn/pnpm):**
```dockerfile
FROM node:22-slim
RUN apt-get update && apt-get install -y git curl jq bash ca-certificates --no-install-recommends \
  && rm -rf /var/lib/apt/lists/*
RUN npm install -g pnpm@9          # if pnpm
RUN npm install -g @anthropic-ai/claude-code
RUN useradd -m -s /bin/bash agent \
  && mkdir -p /home/agent/.claude /workspace /agent \
  && chown -R agent:agent /home/agent /workspace /agent
USER agent
WORKDIR /workspace
```

**Python:**
```dockerfile
FROM python:3.12-slim
RUN apt-get update && apt-get install -y git curl jq bash ca-certificates nodejs npm --no-install-recommends \
  && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir uv    # or poetry, depending on pyproject.toml
RUN npm install -g @anthropic-ai/claude-code
RUN useradd -m -s /bin/bash agent \
  && mkdir -p /home/agent/.claude /workspace /agent \
  && chown -R agent:agent /home/agent /workspace /agent
USER agent
WORKDIR /workspace
```

**Go:**
```dockerfile
FROM golang:1.23-bookworm
RUN apt-get update && apt-get install -y git curl jq bash ca-certificates nodejs npm --no-install-recommends \
  && rm -rf /var/lib/apt/lists/*
RUN npm install -g @anthropic-ai/claude-code
RUN useradd -m -s /bin/bash agent \
  && mkdir -p /home/agent/.claude /workspace /agent \
  && chown -R agent:agent /home/agent /workspace /agent
USER agent
WORKDIR /workspace
```

**Rust:**
```dockerfile
FROM rust:1.83-slim
RUN apt-get update && apt-get install -y git curl jq bash ca-certificates nodejs npm --no-install-recommends \
  && rm -rf /var/lib/apt/lists/*
RUN npm install -g @anthropic-ai/claude-code
RUN useradd -m -s /bin/bash agent \
  && mkdir -p /home/agent/.claude /workspace /agent \
  && chown -R agent:agent /home/agent /workspace /agent
USER agent
WORKDIR /workspace
```

**Shell/bare:**
```dockerfile
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y git curl jq bash ca-certificates nodejs npm make --no-install-recommends \
  && rm -rf /var/lib/apt/lists/*
RUN npm install -g @anthropic-ai/claude-code
RUN useradd -m -s /bin/bash agent \
  && mkdir -p /home/agent/.claude /workspace /agent \
  && chown -R agent:agent /home/agent /workspace /agent
USER agent
WORKDIR /workspace
```

## .agent.md template

```markdown
# Project Conventions

## Stack
[detected stack + versions]

## Package manager
[npm / pnpm / yarn / pip / uv / cargo / go modules / etc.]

## Commands
- **test**: [detected test command]
- **lint**: [detected lint command]
- **build**: [detected build command]
- **typecheck**: [if applicable]

## Key directories
[inferred from project structure]

## Monorepo (omit if not monorepo)
- workspace root: ../../   (relative to this app)
- shared packages: packages/ui, packages/utils
- scope rule: only modify files under apps/webapp/ and the shared packages listed above

## Architecture
[leave blank — user fills this in]

## Rules
- [leave blank — user fills this in]
```

## Anti-patterns

- Guessing versions not found in the project — use latest stable
- Installing both pnpm and npm when lockfile is clear — pick one
- Skipping the `.agent.md` — agents are blind without it

## Output

After writing files:

```
Generated .agent.Dockerfile  (Node 22, pnpm)
Generated .agent.md

Edit .agent.md → Architecture and Rules sections before running agents.
Run: ./.agent/run.sh
```
