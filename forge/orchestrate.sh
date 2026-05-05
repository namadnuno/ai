#!/usr/bin/env bash
# Runs INSIDE the per-project Docker container
set -euo pipefail

RESET='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'
RED='\033[31m';  MAGENTA='\033[35m'

BRANCH="${BRANCH:-feature/agent-run}"
TARGET_BRANCH="${TARGET_BRANCH:-main}"
IMAGE_NAMES="${IMAGE_NAMES:-}"

PROGRAMMER_MODEL="${PROGRAMMER_MODEL:-sonnet}"
REVIEWER_MODEL="${REVIEWER_MODEL:-opus}"
PROGRAMMER_MAX_TURNS="${PROGRAMMER_MAX_TURNS:-15}"
REVIEWER_MAX_TURNS="${REVIEWER_MAX_TURNS:-10}"

MAX_TOKENS_PROGRAMMER="${MAX_TOKENS_PROGRAMMER:-0}"
MAX_TOKENS_REVIEWER="${MAX_TOKENS_REVIEWER:-0}"
MAX_TOKENS_TOTAL="${MAX_TOKENS_TOTAL:-0}"

ALLOW_REVIEWER_FIXES="${ALLOW_REVIEWER_FIXES:-true}"

SPECS_FILE="${SPECS_FILE:-/agent/specs.md}"
BEST_PRACTICES_FILE="${BEST_PRACTICES_FILE:-/agent/best-practices.md}"
IMAGES_DIR="${IMAGES_DIR:-/agent/images}"
PROMPTS_DIR="${PROMPTS_DIR:-/agent/prompts}"
WORKSPACE="${WORKSPACE:-/workspace}"
LOGS_DIR="${LOGS_DIR:-$WORKSPACE/.agent.logs}"
RUN_ID="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$LOGS_DIR"

# ─── Running totals across the run ───
TOTAL_INPUT_TOKENS=0
TOTAL_OUTPUT_TOKENS=0
TOTAL_CACHE_READ=0
TOTAL_CACHE_CREATE=0

# ─────────────────────────────────────────────
print_agent() {
  echo ""
  echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}${CYAN}  $1${RESET}"
  echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}
print_ok()   { echo -e "${GREEN}  ✓ $1${RESET}"; }
print_warn() { echo -e "${YELLOW}  ⚠ $1${RESET}"; }
print_err()  { echo -e "${RED}  ✗ $1${RESET}"; }

fmt_num() { printf "%'d" "$1" 2>/dev/null || echo "$1"; }

# ─────────────────────────────────────────────
build_image_flags() {
  local flags=""
  [ -z "$IMAGE_NAMES" ] && { echo ""; return; }
  IFS=':' read -ra names <<< "$IMAGE_NAMES"
  for n in "${names[@]}"; do
    [ -f "$IMAGES_DIR/$n" ] && flags="$flags --image $IMAGES_DIR/$n"
  done
  echo "$flags"
}

# ─────────────────────────────────────────────
#  Check budget BEFORE running an agent
# ─────────────────────────────────────────────
check_total_budget() {
  [ "$MAX_TOKENS_TOTAL" -eq 0 ] && return
  local current=$((TOTAL_INPUT_TOKENS + TOTAL_OUTPUT_TOKENS))
  if [ "$current" -ge "$MAX_TOKENS_TOTAL" ]; then
    print_err "Total token budget ($(fmt_num $MAX_TOKENS_TOTAL)) reached before this agent could start."
    print_err "Already used: $(fmt_num $current) tokens. Aborting."
    exit 2
  fi
  local remaining=$((MAX_TOKENS_TOTAL - current))
  if [ "$remaining" -lt 50000 ]; then
    print_warn "Only $(fmt_num $remaining) tokens left in total budget."
  fi
}

# ─────────────────────────────────────────────
#  Run a Claude agent and parse usage from stream-json
# ─────────────────────────────────────────────
run_agent() {
  local name="$1"
  local prompt_file="$2"
  local model="$3"
  local max_turns="$4"
  local max_tokens="$5"

  local name_lc; name_lc="$(echo "$name" | tr '[:upper:]' '[:lower:]')"
  local log_file="$LOGS_DIR/${RUN_ID}-${name_lc}.log"
  local stream_file="$LOGS_DIR/${RUN_ID}-${name_lc}.jsonl"

  print_agent "Agent: $name"
  echo -e "  ${DIM}model: $model | max-turns: $max_turns${RESET}"
  if [ "$max_tokens" -gt 0 ]; then
    echo -e "  ${DIM}budget: $(fmt_num $max_tokens) tokens${RESET}"
  fi
  echo -e "  ${DIM}log:   $log_file${RESET}\n"

  check_total_budget

  # Build full prompt
  local full_prompt
  full_prompt="$(sed \
    -e "s|{{BRANCH}}|$BRANCH|g" \
    -e "s|{{TARGET_BRANCH}}|$TARGET_BRANCH|g" \
    -e "s|{{RUN_ID}}|$RUN_ID|g" \
    -e "s|{{ALLOW_FIXES}}|$ALLOW_REVIEWER_FIXES|g" \
    "$prompt_file")"

  full_prompt="${full_prompt}

---
## Project conventions

$(cat "$BEST_PRACTICES_FILE")

---
## Specs

$(cat "$SPECS_FILE")"

  local image_flags; image_flags="$(build_image_flags)"
  if [ -n "$image_flags" ]; then
    IFS=':' read -ra names <<< "$IMAGE_NAMES"
    local list=""
    for n in "${names[@]}"; do list="$list\n- $n"; done
    full_prompt="${full_prompt}

---
## Reference images
$(echo -e "$list")"
  fi

  # ── Run claude with stream-json output ──
  # Stream lines: {"type":"assistant", ...}, {"type":"result", "usage":{...}}
  # We tee the raw JSON to disk, and pipe through jq to display assistant text live.
  set +e
  # shellcheck disable=SC2086
  claude --print \
         --model "$model" \
         --max-turns "$max_turns" \
         --output-format stream-json \
         --include-partial-messages \
         --verbose \
         $image_flags \
         "$full_prompt" 2>&1 \
    | tee "$stream_file" \
    | jq -r --unbuffered '
        if .type == "assistant" then
          (.message.content // [])[]?
          | select(.type == "text")
          | .text
        elif .type == "user" and (.message.content[0].type // "") == "tool_result" then
          # Suppress tool_result echoes
          empty
        else empty end
      ' 2>/dev/null \
    | tee "$log_file"
  local rc=${PIPESTATUS[0]}
  set -e

  echo ""

  if [ $rc -ne 0 ]; then
    print_err "$name failed (exit $rc)"
    print_err "Check stream: $stream_file"
    exit 1
  fi

  # ── Parse usage from the final result message ──
  local usage_json=""
  if [ -s "$stream_file" ]; then
    usage_json="$(grep '"type":"result"' "$stream_file" | tail -1 || true)"
  fi

  local in_t=0 out_t=0 cr=0 cc=0
  if [ -n "$usage_json" ]; then
    in_t=$(echo "$usage_json" | jq -r '.usage.input_tokens // 0' 2>/dev/null || echo 0)
    out_t=$(echo "$usage_json" | jq -r '.usage.output_tokens // 0' 2>/dev/null || echo 0)
    cr=$(echo "$usage_json"   | jq -r '.usage.cache_read_input_tokens // 0' 2>/dev/null || echo 0)
    cc=$(echo "$usage_json"   | jq -r '.usage.cache_creation_input_tokens // 0' 2>/dev/null || echo 0)
  else
    print_warn "Could not parse usage from stream output."
  fi

  local agent_total=$((in_t + out_t))

  # ── Update running totals ──
  TOTAL_INPUT_TOKENS=$((TOTAL_INPUT_TOKENS + in_t))
  TOTAL_OUTPUT_TOKENS=$((TOTAL_OUTPUT_TOKENS + out_t))
  TOTAL_CACHE_READ=$((TOTAL_CACHE_READ + cr))
  TOTAL_CACHE_CREATE=$((TOTAL_CACHE_CREATE + cc))

  local run_total=$((TOTAL_INPUT_TOKENS + TOTAL_OUTPUT_TOKENS))

  # ── Summary for this agent ──
  echo ""
  echo -e "  ${BOLD}${MAGENTA}── Token usage ──${RESET}"
  echo -e "  ${DIM}input:${RESET}      $(fmt_num $in_t)"
  echo -e "  ${DIM}output:${RESET}     $(fmt_num $out_t)"
  if [ "$cr" -gt 0 ] || [ "$cc" -gt 0 ]; then
    echo -e "  ${DIM}cache read:${RESET}  $(fmt_num $cr)"
    echo -e "  ${DIM}cache write:${RESET} $(fmt_num $cc)"
  fi
  echo -e "  ${BOLD}agent total: $(fmt_num $agent_total)${RESET}"
  if [ "$max_tokens" -gt 0 ]; then
    local pct=$((agent_total * 100 / max_tokens))
    if [ "$agent_total" -gt "$max_tokens" ]; then
      echo -e "  ${RED}⚠ exceeded budget by $(fmt_num $((agent_total - max_tokens))) tokens (${pct}% of $(fmt_num $max_tokens))${RESET}"
    else
      echo -e "  ${DIM}budget used: ${pct}% of $(fmt_num $max_tokens)${RESET}"
    fi
  fi
  if [ "$MAX_TOKENS_TOTAL" -gt 0 ]; then
    local pct_total=$((run_total * 100 / MAX_TOKENS_TOTAL))
    echo -e "  ${DIM}run total:   $(fmt_num $run_total) / $(fmt_num $MAX_TOKENS_TOTAL) (${pct_total}%)${RESET}"
  else
    echo -e "  ${DIM}run total:   $(fmt_num $run_total)${RESET}"
  fi
  echo ""

  # ── Hard abort if total exceeded ──
  if [ "$MAX_TOKENS_TOTAL" -gt 0 ] && [ "$run_total" -ge "$MAX_TOKENS_TOTAL" ]; then
    print_err "Total token budget exhausted. Aborting before next agent."
    save_summary
    exit 2
  fi

  print_ok "$name done"
}

# ─────────────────────────────────────────────
save_summary() {
  local summary="$LOGS_DIR/${RUN_ID}-summary.md"
  local run_total=$((TOTAL_INPUT_TOKENS + TOTAL_OUTPUT_TOKENS))
  cat > "$summary" <<EOF
# Run summary — $RUN_ID

- Branch: \`$BRANCH\` → \`$TARGET_BRANCH\`
- Programmer model: \`$PROGRAMMER_MODEL\`
- Reviewer model: \`$REVIEWER_MODEL\`

## Token usage

| | tokens |
|---|---:|
| Input  | $(fmt_num $TOTAL_INPUT_TOKENS) |
| Output | $(fmt_num $TOTAL_OUTPUT_TOKENS) |
| Cache read | $(fmt_num $TOTAL_CACHE_READ) |
| Cache write | $(fmt_num $TOTAL_CACHE_CREATE) |
| **Total (input+output)** | **$(fmt_num $run_total)** |

EOF
  print_ok "Summary saved: $summary"
}

# ─────────────────────────────────────────────
setup_git() {
  print_agent "Git Setup"
  cd "$WORKSPACE"
  git config user.email 2>/dev/null || git config user.email "agent@pipeline.local"
  git config user.name  2>/dev/null || git config user.name  "Agent Pipeline"

  local base; base="$(git rev-parse --abbrev-ref HEAD)"
  if git rev-parse --verify "$BRANCH" &>/dev/null; then
    print_warn "Branch exists — resetting"
    git checkout "$BRANCH"; git reset --hard HEAD
  else
    git checkout -b "$BRANCH"
    print_ok "Created $BRANCH (from $base)"
  fi
}

# ─────────────────────────────────────────────
push_and_get_mr_url() {
  print_agent "Push → GitLab MR"
  cd "$WORKSPACE"
  git push origin "$BRANCH" --force-with-lease 2>&1 \
    || { print_err "Push failed."; exit 1; }
  print_ok "Pushed $BRANCH"

  local remote_url; remote_url="$(git remote get-url origin)"
  local web_url
  if [[ "$remote_url" =~ ^git@ ]]; then
    web_url="${remote_url#git@}"; web_url="${web_url/://}"
    web_url="https://${web_url%.git}"
  else
    web_url="${remote_url%.git}"
  fi
  local mr_url="${web_url}/-/merge_requests/new?merge_request[source_branch]=${BRANCH}&merge_request[target_branch]=${TARGET_BRANCH}"
  echo "$mr_url" > "$LOGS_DIR/.mr-url"
  print_ok "MR URL ready"
}

# ─────────────────────────────────────────────
echo ""
echo -e "${BOLD}${MAGENTA}  🚀 Pipeline  —  $RUN_ID${RESET}"
echo -e "${DIM}  Branch: $BRANCH → $TARGET_BRANCH${RESET}"
echo -e "${DIM}  Models: programmer=$PROGRAMMER_MODEL  reviewer=$REVIEWER_MODEL${RESET}"

setup_git
run_agent "Programmer" "$PROMPTS_DIR/programmer.md" "$PROGRAMMER_MODEL" "$PROGRAMMER_MAX_TURNS" "$MAX_TOKENS_PROGRAMMER"
run_agent "Reviewer"   "$PROMPTS_DIR/reviewer.md"   "$REVIEWER_MODEL"   "$REVIEWER_MAX_TURNS"   "$MAX_TOKENS_REVIEWER"
push_and_get_mr_url
save_summary

echo ""
echo -e "${BOLD}${GREEN}  ✓ Done!${RESET}"
echo -e "  ${DIM}Total tokens: $(fmt_num $((TOTAL_INPUT_TOKENS + TOTAL_OUTPUT_TOKENS)))${RESET}"
echo ""
