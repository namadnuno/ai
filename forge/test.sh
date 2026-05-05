#!/usr/bin/env bash
# forge/test.sh — dry-run orchestrate.sh without Docker or real Claude
# Usage: bash forge/test.sh
set -euo pipefail

RESET='\033[0m'; BOLD='\033[1m'; GREEN='\033[32m'; RED='\033[31m'
CYAN='\033[36m'; YELLOW='\033[33m'; DIM='\033[2m'

FORGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pass() { echo -e "${GREEN}  ✓ $1${RESET}"; }
fail() { echo -e "${RED}  ✗ $1${RESET}"; FAILURES=$((FAILURES + 1)); }
step() { echo -e "\n${BOLD}${CYAN}▶ $1${RESET}"; }

FAILURES=0
WORK_DIR="$(mktemp -d /tmp/forge-test-XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

# ─── Fake binaries ───────────────────────────────────────────────
FAKE_BIN="$WORK_DIR/bin"
mkdir -p "$FAKE_BIN"

# git wrapper: intercept push (no remote), pass everything else through
cat > "$FAKE_BIN/git" <<EOF
#!/usr/bin/env bash
if [ "\$1" = "push" ]; then
  echo "  [test] git push skipped"
  exit 0
fi
exec "$(which git)" "\$@"
EOF
chmod +x "$FAKE_BIN/git"

cat > "$FAKE_BIN/claude" <<'EOF'
#!/usr/bin/env bash
# Emits minimal valid stream-json, then writes a sentinel commit so orchestrate
# can verify the programmer actually "ran" (reviewer checks the diff).
cd /workspace 2>/dev/null || true
echo '{"type":"assistant","message":{"content":[{"type":"text","text":"[mock] running"}]}}'

# Let programmer write a file so reviewer has a diff to check
if echo "$*" | grep -q "programmer\|programmer"; then
  echo "mock" >> mock-output.txt
  git add mock-output.txt 2>/dev/null || true
  git commit -m "feat: mock programmer output" 2>/dev/null || true
fi

echo '{"type":"result","subtype":"success","is_error":false,"usage":{"input_tokens":42,"output_tokens":17,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}'
EOF
chmod +x "$FAKE_BIN/claude"

# ─── Fake git repo ────────────────────────────────────────────────
REPO="$WORK_DIR/repo"
git init -q "$REPO"
git -C "$REPO" config user.email "test@test.local"
git -C "$REPO" config user.name "Test"
# need at least one commit on main so branches have a base
echo "init" > "$REPO/README.md"
git -C "$REPO" add README.md
git -C "$REPO" commit -q -m "chore: init"
git -C "$REPO" remote add origin "git@example.com:test/repo.git" 2>/dev/null || true

# ─── Stub agent/ inputs ───────────────────────────────────────────
    mkdir -p "$WORK_DIR/agent/prompts" "$WORK_DIR/agent/images"
cp "$FORGE_DIR/prompts/programmer.md" "$WORK_DIR/agent/prompts/programmer.md"
cp "$FORGE_DIR/prompts/reviewer.md"   "$WORK_DIR/agent/prompts/reviewer.md"

cat > "$WORK_DIR/agent/specs.md" <<'EOF'
---
title: "Test spec"
---
Write a file called mock-output.txt with the text "mock".
EOF

cat > "$WORK_DIR/agent/best-practices.md" <<'EOF'
# Conventions
- Keep it simple
EOF

ORCH_COPY="$FORGE_DIR/orchestrate.sh"

# ─── Run ──────────────────────────────────────────────────────────
step "Running orchestrate.sh with mock claude"
echo -e "  ${DIM}repo:    $REPO${RESET}"
echo -e "  ${DIM}workdir: $WORK_DIR${RESET}\n"

export PATH="$FAKE_BIN:$PATH"

set +e
WORKSPACE="$REPO" \
SPECS_FILE="$WORK_DIR/agent/specs.md" \
BEST_PRACTICES_FILE="$WORK_DIR/agent/best-practices.md" \
IMAGES_DIR="$WORK_DIR/agent/images" \
PROMPTS_DIR="$WORK_DIR/agent/prompts" \
LOGS_DIR="$REPO/.agent.logs" \
BRANCH="feature/test-run" \
TARGET_BRANCH="main" \
PROGRAMMER_MODEL="sonnet" \
REVIEWER_MODEL="sonnet" \
PROGRAMMER_MAX_TURNS=3 \
REVIEWER_MAX_TURNS=3 \
MAX_TOKENS_PROGRAMMER=0 \
MAX_TOKENS_REVIEWER=0 \
MAX_TOKENS_TOTAL=0 \
ALLOW_REVIEWER_FIXES=true \
  bash "$ORCH_COPY" 2>&1
EXIT_CODE=$?
set -e

# ─── Assertions ───────────────────────────────────────────────────
step "Assertions"

if [ $EXIT_CODE -eq 0 ]; then
  pass "orchestrate.sh exited 0"
else
  fail "orchestrate.sh exited $EXIT_CODE"
fi

if git -C "$REPO" rev-parse --verify "feature/test-run" &>/dev/null; then
  pass "branch feature/test-run created"
else
  fail "branch feature/test-run not found"
fi

LOG_COUNT=$(ls "$REPO/.agent.logs/"*.jsonl 2>/dev/null | wc -l || echo 0)
if [ "$LOG_COUNT" -ge 2 ]; then
  pass "stream log files written ($LOG_COUNT)"
else
  fail "expected ≥2 stream logs, got $LOG_COUNT"
fi

SUMMARY=$(ls "$REPO/.agent.logs/"*-summary.md 2>/dev/null | head -1 || echo "")
if [ -f "$SUMMARY" ]; then
  pass "summary.md written"
else
  fail "summary.md not found"
fi

# ─── Result ───────────────────────────────────────────────────────
echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo -e "${BOLD}${GREEN}  All tests passed.${RESET}"
else
  echo -e "${BOLD}${RED}  $FAILURES test(s) failed.${RESET}"
  exit 1
fi
