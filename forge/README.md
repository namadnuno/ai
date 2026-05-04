# Agent Pipeline

Portable multi-agent coding pipeline.
**Programmer → Reviewer → push branch → open GitLab MR**

Designed to drop into any repo with a single `.agent/` folder, then customised per project via two files.

## How portability works

The `.agent/` folder is **identical across all your projects** — copy it as-is.

Per-project customisation lives in **two files at the repo root** that you edit once:

| File | Purpose | Created on first run |
|---|---|---|
| `.agent.Dockerfile` | Defines the sandbox runtime (Node? Python? Go? Postgres client? etc.) | yes — from template |
| `.agent.md` | Project conventions, architecture rules, lint/test commands | yes — from template |
| `.agent.config` | Optional bash config (target branch, max turns, etc.) | no — opt-in |

On the **first run** in a new repo, the script copies the templates into your repo root and exits, asking you to edit them. From the second run onwards, the pipeline just runs.

## Install in a new project

```bash
# One-liner — fetches forge from GitHub, drops it as .agent/ in your repo
curl -fsSL https://raw.githubusercontent.com/namadnuno/ai/main/forge/install.sh | bash
```

Or without curl:

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/namadnuno/ai.git _forge \
  && git -C _forge sparse-checkout set forge \
  && cp -r _forge/forge .agent \
  && chmod +x .agent/*.sh \
  && rm -rf _forge
```

Then first run bootstraps per-project config:

```bash
# Generates .agent.Dockerfile and .agent.md, then exits
./.agent/run.sh

# Edit for your project
$EDITOR .agent.Dockerfile
$EDITOR .agent.md

# Ready — run the pipeline
./.agent/run.sh
```

## What's in the box (don't edit)

```
.agent/
├── run.sh                     ← interactive entry point
├── orchestrate.sh             ← pipeline logic (runs in container)
├── prompts/
│   ├── programmer.md          ← role-only; reads conventions from .agent.md
│   └── reviewer.md            ← role-only; reads conventions from .agent.md
└── templates/
    ├── Dockerfile.template
    ├── best-practices.template.md
    └── agent.config.template
```

The prompts are **generic role descriptions**. They don't know anything about your project — they read your `.agent.md` at runtime to learn the conventions. This is what makes the same `.agent/` folder portable.

## What lives in your repo (you edit)

```
your-repo/
├── .agent/                    ← portable, identical across projects
├── .agent.Dockerfile          ← per-project: stack & tools
├── .agent.md                  ← per-project: conventions & rules
├── .agent.config              ← optional: target branch, turn limits
├── .agent.logs/               ← gitignored, run logs
└── (your code)
```

## Updating the pipeline across all your projects

Because `.agent/` is identical everywhere, updating is just re-running the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/namadnuno/ai/main/forge/install.sh | bash
```

Your `.agent.Dockerfile` and `.agent.md` are untouched — the installer only replaces `.agent/`.

## What to put in `.agent.md`

Be specific. Generic statements ("write clean code") get ignored. Concrete rules ("all DB queries go through `src/db/queries/`") shape the output. The template has examples — replace them with your project's actual conventions.

The reviewer will check the implementation against these rules and either fix violations or block the run, depending on `ALLOW_REVIEWER_FIXES`.

## Auth & dependencies

The script auto-installs missing dependencies on first run:
- **macOS**: `git`, Docker Desktop (via brew if available), `claude` CLI
- **Fedora**: `git`, `docker`, `wl-clipboard` or `xclip`, `claude` CLI
- **Debian/Ubuntu**: same as Fedora, via `apt`

Claude Code uses your **subscription** (no API key). Run `claude` once to log in; the script copies `~/.claude` into the container at runtime.

## Adding images to the prompt

The CLI lets you add screenshots/mockups via:
- **`c`** — paste from clipboard (Cmd+Shift+4 on macOS, screenshot tool on Linux)
- **`f`** — file path or drag-drop into the terminal

Both agents see the images.

## GitLab integration

After the reviewer approves, the pipeline pushes the branch and opens the GitLab "new MR" page in your browser with `source_branch` and `target_branch` pre-filled. You finish the MR description and submit.

Default target is `main`. Override per-project in `.agent.config`:

```bash
TARGET_BRANCH="develop"
```
