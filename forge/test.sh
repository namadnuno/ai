#!/usr/bin/env bash
# forge/test.sh — integration test: real Claude, real Docker, runs start.sh with 3 tiny specs
# Usage: bash forge/test.sh
set -euo pipefail

RESET='\033[0m'; BOLD='\033[1m'; GREEN='\033[32m'; RED='\033[31m'
CYAN='\033[36m'; YELLOW='\033[33m'; DIM='\033[2m'

FORGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$FORGE_DIR" rev-parse --show-toplevel)"
RUNS_DIR="$REPO_ROOT/forge-test-runs"
FAILURES=0

pass() { echo -e "${GREEN}  ✓ $1${RESET}"; }
fail() { echo -e "${RED}  ✗ $1${RESET}"; FAILURES=$((FAILURES + 1)); }
step() { echo -e "\n${BOLD}${CYAN}▶ $1${RESET}"; }

# ─── Persistent test project dir (gitignored, watchable) ─────────
mkdir -p "$RUNS_DIR"
PROJECT="$RUNS_DIR/run-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$PROJECT"

step "Setting up test project at $PROJECT"

# Minimal git repo
git init -q "$PROJECT"
git -C "$PROJECT" config user.email "test@forge.local"
git -C "$PROJECT" config user.name "Forge Test"

# Source file the agents will modify
cat > "$PROJECT/index.js" <<'EOF'
function greet(name) {
  return `Hello, ${name}!`;
}

module.exports = { greet };
EOF
git -C "$PROJECT" add index.js
git -C "$PROJECT" commit -q -m "chore: init"

# ─── Install forge as .agent/ ────────────────────────────────────
cp -r "$FORGE_DIR" "$PROJECT/.agent"
chmod +x "$PROJECT/.agent/run.sh" "$PROJECT/.agent/start.sh" \
         "$PROJECT/.agent/review.sh" "$PROJECT/.agent/orchestrate.sh"
echo -e "  ${DIM}forge installed → $PROJECT/.agent/${RESET}"

# ─── .agent.Dockerfile ───────────────────────────────────────────
cat > "$PROJECT/.agent.Dockerfile" <<'EOF'
FROM node:22-slim
RUN apt-get update && apt-get install -y \
    git curl jq bash ca-certificates \
    --no-install-recommends \
  && rm -rf /var/lib/apt/lists/*
RUN npm install -g @anthropic-ai/claude-code
RUN mkdir -p /workspace /agent && chmod 777 /workspace /agent
WORKDIR /workspace
EOF

# ─── .agent.md ───────────────────────────────────────────────────
cat > "$PROJECT/.agent.md" <<'EOF'
# Conventions
- Plain Node.js, no framework
- index.js is the main file
- Commit with conventional commits (feat:, fix:, chore:)
- No tests required for this task
EOF

# ─── .agent.config ───────────────────────────────────────────────
cat > "$PROJECT/.agent.config" <<'EOF'
PROGRAMMER_MODEL="sonnet"
REVIEWER_MODEL="sonnet"
PROGRAMMER_MAX_TURNS=8
REVIEWER_MAX_TURNS=8
MAX_TOKENS_PROGRAMMER=100000
MAX_TOKENS_REVIEWER=50000
MAX_TOKENS_TOTAL=600000
EOF

# ─── Specs ───────────────────────────────────────────────────────
mkdir -p "$PROJECT/.agent.queue/pending"

cat > "$PROJECT/.agent.queue/pending/spec-001.md" <<'EOF'
---
id: spec-001
title: Add startup log
depends_on:
---

# Task

In `index.js`, add `console.log("app started")` as the very first line of the file.

## Acceptance criteria

- [ ] First line of index.js is exactly: `console.log("app started")`
EOF

cat > "$PROJECT/.agent.queue/pending/spec-002.md" <<'EOF'
---
id: spec-002
title: Add greet log
depends_on: spec-001
---

# Task

In `index.js`, inside the `greet` function body, add `console.log("greet called")` as the first statement.

## Acceptance criteria

- [ ] greet() logs "greet called" before returning
EOF

cat > "$PROJECT/.agent.queue/pending/spec-003.md" <<'EOF'
---
id: spec-003
title: Add version constant
depends_on: spec-002
---

# Task

In `index.js`, add a `const VERSION = "1.0.0"` constant after the existing requires/imports (or at the top if there are none), then export it: add `VERSION` to the `module.exports` object.

## Acceptance criteria

- [ ] VERSION constant defined as "1.0.0"
- [ ] VERSION exported from module.exports
EOF

echo -e "  ${DIM}3 specs written to .agent.queue/pending/${RESET}"

# ─── Run start.sh ────────────────────────────────────────────────
step "Running start.sh (real Claude, real Docker)"
echo -e "  ${YELLOW}Building Docker image and running 3 agent pipelines.${RESET}"
echo -e "  ${DIM}Watch queue:  watch -n1 'find $PROJECT/.agent.queue -name \"*.md\" | sort'${RESET}"
echo -e "  ${DIM}Watch logs:   tail -f $PROJECT/.agent.logs/*.log${RESET}\n"

cd "$PROJECT"
bash "$PROJECT/.agent/start.sh"

# ─── Assertions ──────────────────────────────────────────────────
step "Assertions"

for id in spec-001 spec-002 spec-003; do
  if [ -f "$PROJECT/.agent.queue/done/${id}.md" ]; then
    pass "$id → done"
  elif [ -f "$PROJECT/.agent.queue/failed/${id}.md" ]; then
    fail "$id → failed (check .agent.logs/)"
  else
    fail "$id → not processed"
  fi
done

FAIL_COUNT=$(find "$PROJECT/.agent.queue/failed" -name "*.md" 2>/dev/null | wc -l)
[ "$FAIL_COUNT" -eq 0 ] && pass "no failed specs" || fail "$FAIL_COUNT spec(s) failed"

# ─── Result ──────────────────────────────────────────────────────
echo ""
echo -e "  ${DIM}Run dir:  $PROJECT${RESET}"
echo -e "  ${DIM}Logs:     $PROJECT/.agent.logs/${RESET}"
echo -e "  ${DIM}Queue:    $PROJECT/.agent.queue/${RESET}"
if [ "$FAILURES" -eq 0 ]; then
  echo -e "${BOLD}${GREEN}  All tests passed.${RESET}"
else
  echo -e "${BOLD}${RED}  $FAILURES test(s) failed.${RESET}"
  exit 1
fi
