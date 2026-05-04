#!/usr/bin/env bash
# .agent/start.sh — Queue orchestrator: process specs in dependency order, parallel
set -euo pipefail

RESET='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'
RED='\033[31m';  MAGENTA='\033[35m'; BLUE='\033[34m'

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$AGENT_DIR" rev-parse --show-toplevel 2>/dev/null || pwd)"
QUEUE_DIR="$REPO_ROOT/.agent.queue"
PROJECT_DOCKERFILE="$REPO_ROOT/.agent.Dockerfile"
PROJECT_BEST_PRACTICES="$REPO_ROOT/.agent.md"
PROJECT_CONFIG="$REPO_ROOT/.agent.config"
LOGS_DIR="$REPO_ROOT/.agent.logs"
REPO_NAME="$(basename "$REPO_ROOT")"
IMAGE_NAME="agent-pipeline-${REPO_NAME,,}:latest"

# ─── Defaults (overridable via .agent.config) ────────────────────
TARGET_BRANCH="main"
PROGRAMMER_MODEL="sonnet"
REVIEWER_MODEL="opus"
PROGRAMMER_MAX_TURNS=15
REVIEWER_MAX_TURNS=10
MAX_TOKENS_PROGRAMMER=500000
MAX_TOKENS_REVIEWER=300000
MAX_TOKENS_TOTAL=1000000
ALLOW_REVIEWER_FIXES=true
POLL_INTERVAL=5

print_ok()   { echo -e "${GREEN}  ✓ $1${RESET}"; }
print_warn() { echo -e "${YELLOW}  ⚠ $1${RESET}"; }
print_err()  { echo -e "${RED}  ✗ $1${RESET}"; }
print_step() { echo -e "\n${BOLD}${BLUE}▶ $1${RESET}"; }
print_spec() { echo -e "${BOLD}${CYAN}  [$1]${RESET} $2"; }

# ─── Spec frontmatter parsing ────────────────────────────────────
get_field() {
  local file="$1" key="$2"
  grep -m1 "^${key}:" "$file" 2>/dev/null | sed "s/^${key}: *//" | tr -d '"' || echo ""
}

spec_id()      { get_field "$1" "id"; }
spec_title()   { get_field "$1" "title"; }
spec_branch()  { get_field "$1" "branch"; }
spec_deps()    { get_field "$1" "depends_on"; }

# ─── Dependency check ────────────────────────────────────────────
deps_resolved() {
  local deps; deps="$(spec_deps "$1")"
  [ -z "$deps" ] && return 0
  IFS=',' read -ra list <<< "$deps"
  for dep in "${list[@]}"; do
    dep="${dep// /}"
    [ -z "$dep" ] && continue
    [ -f "$QUEUE_DIR/done/${dep}.md" ] || return 1
  done
  return 0
}

# ─── Run single agent pipeline (non-interactive) ─────────────────
launch_agent() {
  local id="$1" spec_file="$2"
  local branch; branch="$(spec_branch "$spec_file")"
  local title; title="$(spec_title "$spec_file")"
  local run_id; run_id="$(date +%Y%m%d-%H%M%S)-${id}"
  local log_file="$LOGS_DIR/${run_id}.log"

  mkdir -p "$LOGS_DIR"

  echo -e "\n${MAGENTA}  🚀 Launching ${BOLD}${id}${RESET}${MAGENTA}: ${title}${RESET}"
  echo -e "  ${DIM}branch: $branch  |  log: $log_file${RESET}"

  local bp_tmp; bp_tmp="$(mktemp /tmp/agent-bp-XXXXXX.md)"
  [ -f "$PROJECT_BEST_PRACTICES" ] && cp "$PROJECT_BEST_PRACTICES" "$bp_tmp" \
                                   || echo "# (no conventions)" > "$bp_tmp"

  local claude_tmp; claude_tmp="$(mktemp -d /tmp/claude-cfg-XXXXXX)"
  [ -d "$HOME/.claude" ] && cp -r "$HOME/.claude/." "$claude_tmp/"

  local ssh_mount=""; [ -d "$HOME/.ssh" ] && ssh_mount="-v $HOME/.ssh:/home/agent/.ssh:ro"
  local git_mount=""; [ -f "$HOME/.gitconfig" ] && git_mount="-v $HOME/.gitconfig:/home/agent/.gitconfig:ro"

  local exit_code=0
  docker run --rm \
    -v "$REPO_ROOT:/workspace" \
    -v "$AGENT_DIR/prompts:/agent/prompts:ro" \
    -v "$AGENT_DIR/orchestrate.sh:/agent/orchestrate.sh:ro" \
    -v "$spec_file:/agent/specs.md:ro" \
    -v "$bp_tmp:/agent/best-practices.md:ro" \
    -v "$claude_tmp:/home/agent/.claude" \
    $ssh_mount $git_mount \
    -e BRANCH="$branch" \
    -e TARGET_BRANCH="$TARGET_BRANCH" \
    -e IMAGE_NAMES="" \
    -e PROGRAMMER_MODEL="$PROGRAMMER_MODEL" \
    -e REVIEWER_MODEL="$REVIEWER_MODEL" \
    -e PROGRAMMER_MAX_TURNS="$PROGRAMMER_MAX_TURNS" \
    -e REVIEWER_MAX_TURNS="$REVIEWER_MAX_TURNS" \
    -e MAX_TOKENS_PROGRAMMER="$MAX_TOKENS_PROGRAMMER" \
    -e MAX_TOKENS_REVIEWER="$MAX_TOKENS_REVIEWER" \
    -e MAX_TOKENS_TOTAL="$MAX_TOKENS_TOTAL" \
    -e ALLOW_REVIEWER_FIXES="$ALLOW_REVIEWER_FIXES" \
    -w /workspace \
    "$IMAGE_NAME" \
    bash /agent/orchestrate.sh > "$log_file" 2>&1 || exit_code=$?

  rm -f "$bp_tmp"
  rm -rf "$claude_tmp"

  if [ $exit_code -eq 0 ]; then
    mv "$QUEUE_DIR/running/${id}.md" "$QUEUE_DIR/done/${id}.md"
    print_ok "Done: ${id} → ${branch}"
  else
    mv "$QUEUE_DIR/running/${id}.md" "$QUEUE_DIR/failed/${id}.md"
    print_err "Failed: ${id} (exit $exit_code) — see $log_file"
  fi
}

# ─── Main loop ───────────────────────────────────────────────────
mkdir -p "$QUEUE_DIR"/{pending,running,done,failed} "$LOGS_DIR"

[ -f "$PROJECT_CONFIG" ] && source "$PROJECT_CONFIG"

echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║       🤖  Agent Queue Orchestrator       ║${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════╝${RESET}"
echo -e "${DIM}  project: ${REPO_NAME}  |  queue: .agent.queue/${RESET}"
echo ""

# Ensure Docker image is current
print_step "Docker image"
if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
  echo -e "  ${DIM}Building...${RESET}"
  docker build -t "$IMAGE_NAME" -f "$PROJECT_DOCKERFILE" "$REPO_ROOT" --quiet
fi
print_ok "$IMAGE_NAME"

# Recover interrupted specs (running/ → pending/ on startup)
for f in "$QUEUE_DIR/running/"*.md; do
  [ -f "$f" ] || continue
  id="$(spec_id "$f")"
  print_warn "Recovering interrupted: $id"
  mv "$f" "$QUEUE_DIR/pending/${id}.md"
done

declare -A PIDS  # id → pid

print_step "Processing queue"

while true; do
  # Collect active pids
  for id in "${!PIDS[@]}"; do
    pid="${PIDS[$id]}"
    kill -0 "$pid" 2>/dev/null || unset PIDS["$id"]
  done

  # Dispatch ready specs
  for spec in "$QUEUE_DIR/pending/"*.md; do
    [ -f "$spec" ] || continue
    id="$(spec_id "$spec")"
    [ -z "$id" ] && continue
    deps_resolved "$spec" || continue

    mv "$spec" "$QUEUE_DIR/running/${id}.md"
    launch_agent "$id" "$QUEUE_DIR/running/${id}.md" &
    PIDS[$id]=$!
  done

  pending=$(find "$QUEUE_DIR/pending" -name "*.md" 2>/dev/null | wc -l)
  running=$(find "$QUEUE_DIR/running" -name "*.md" 2>/dev/null | wc -l)

  [ "$pending" -eq 0 ] && [ "$running" -eq 0 ] && break

  echo -e "  ${DIM}pending: $pending  running: $running  — next check in ${POLL_INTERVAL}s${RESET}"
  sleep "$POLL_INTERVAL"
done

# Wait for any remaining background jobs
wait

done_count=$(find "$QUEUE_DIR/done"   -name "*.md" 2>/dev/null | wc -l)
fail_count=$(find "$QUEUE_DIR/failed" -name "*.md" 2>/dev/null | wc -l)

echo ""
echo -e "${BOLD}${GREEN}  ✓ Queue empty.${RESET}"
echo -e "  ${DIM}done: $done_count  failed: $fail_count${RESET}"
echo ""
[ "$fail_count" -gt 0 ] && echo -e "  ${YELLOW}⚠ Failed specs in .agent.queue/failed/ — check logs in .agent.logs/${RESET}\n"
echo -e "  Run ${BOLD}.agent/review.sh${RESET} to inspect and merge branches."
echo ""
