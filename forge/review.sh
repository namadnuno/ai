#!/usr/bin/env bash
# .agent/review.sh — Mini TUI: inspect agent branches, approve, merge
set -euo pipefail

RESET='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'
RED='\033[31m';  MAGENTA='\033[35m'; BLUE='\033[34m'

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$AGENT_DIR" rev-parse --show-toplevel 2>/dev/null || pwd)"
QUEUE_DIR="$REPO_ROOT/.agent.queue"

PROJECT_CONFIG="$REPO_ROOT/.agent.config"
TARGET_BRANCH="main"
[ -f "$PROJECT_CONFIG" ] && source "$PROJECT_CONFIG"

HAS_FZF=false; command -v fzf &>/dev/null && HAS_FZF=true

get_field() {
  local file="$1" key="$2"
  grep -m1 "^${key}:" "$file" 2>/dev/null | sed "s/^${key}: *//" | tr -d '"' || echo ""
}

print_header() {
  clear
  echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${CYAN}║       🔍  Agent Branch Review            ║${RESET}"
  echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════╝${RESET}"
  echo ""
}

# ─── Load done specs ─────────────────────────────────────────────
load_specs() {
  SPEC_FILES=(); SPEC_IDS=(); SPEC_TITLES=(); SPEC_BRANCHES=(); APPROVED=()
  for f in "$QUEUE_DIR/done/"*.md; do
    [ -f "$f" ] || continue
    local id title branch
    id="$(get_field "$f" "id")"
    title="$(get_field "$f" "title")"
    branch="$(get_field "$f" "branch")"
    [ -z "$id" ] && continue
    SPEC_FILES+=("$f")
    SPEC_IDS+=("$id")
    SPEC_TITLES+=("$title")
    SPEC_BRANCHES+=("$branch")
    APPROVED+=("skip")
  done
}

# ─── Show spec list ───────────────────────────────────────────────
show_list() {
  echo -e "  ${BOLD}Done specs${RESET}\n"
  local i
  for i in "${!SPEC_IDS[@]}"; do
    local status="${APPROVED[$i]}"
    local marker
    case "$status" in
      approve) marker="${GREEN}[✓]${RESET}" ;;
      skip)    marker="${DIM}[ ]${RESET}" ;;
    esac
    echo -e "  $marker ${BOLD}$((i+1)).${RESET} ${SPEC_IDS[$i]} — ${SPEC_TITLES[$i]}"
    echo -e "       ${DIM}branch: ${SPEC_BRANCHES[$i]}${RESET}"
  done
  echo ""
}

# ─── Inspect a spec ──────────────────────────────────────────────
inspect() {
  local i=$1
  local branch="${SPEC_BRANCHES[$i]}"
  local orig_branch; orig_branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"

  echo -e "\n${BOLD}${BLUE}── ${SPEC_IDS[$i]}: ${SPEC_TITLES[$i]} ──${RESET}"
  echo -e "${DIM}branch: $branch${RESET}\n"

  if git -C "$REPO_ROOT" rev-parse --verify "$branch" &>/dev/null; then
    echo -e "${BOLD}Diff stats:${RESET}"
    git -C "$REPO_ROOT" diff --stat "${TARGET_BRANCH}...${branch}" 2>/dev/null || echo "  (no diff)"
    echo ""

    read -rp "$(echo -e "  ${CYAN}Checkout to inspect? [y/N]:${RESET} ")" c
    if [[ "${c,,}" == "y"* ]]; then
      git -C "$REPO_ROOT" checkout "$branch"
      echo -e "\n  ${DIM}On branch ${branch}. Commands:${RESET}"
      echo -e "  ${DIM}  git diff ${TARGET_BRANCH}...HEAD   — full diff${RESET}"
      echo -e "  ${DIM}  git log ${TARGET_BRANCH}..HEAD --oneline   — commits${RESET}"
      echo ""
      read -rp "$(echo -e "  ${CYAN}Press Enter to return to review...${RESET} ")" _
      git -C "$REPO_ROOT" checkout "$orig_branch"
    fi
  else
    echo -e "  ${YELLOW}⚠ Branch not found locally: $branch${RESET}"
    echo -e "  ${DIM}Agent may have pushed to remote only.${RESET}"
  fi
}

# ─── Main TUI loop ───────────────────────────────────────────────
load_specs

if [ ${#SPEC_IDS[@]} -eq 0 ]; then
  echo -e "${YELLOW}  No done specs in .agent.queue/done/${RESET}"
  echo -e "  ${DIM}Run start.sh first.${RESET}\n"
  exit 0
fi

while true; do
  print_header
  show_list

  echo -e "  ${BOLD}Commands:${RESET}"
  echo -e "  ${DIM}[1-${#SPEC_IDS[@]}]${RESET} toggle approve/skip"
  echo -e "  ${DIM}[i<n>]${RESET} inspect branch (e.g. i1)"
  echo -e "  ${DIM}[a]${RESET} approve all  ${DIM}[n]${RESET} skip all"
  echo -e "  ${DIM}[m]${RESET} merge approved  ${DIM}[q]${RESET} quit"
  echo ""
  read -rp "$(echo -e "  ${CYAN}> ${RESET}")" cmd

  case "${cmd,,}" in
    q|quit) echo ""; exit 0 ;;
    a) for i in "${!APPROVED[@]}"; do APPROVED[$i]="approve"; done ;;
    n) for i in "${!APPROVED[@]}"; do APPROVED[$i]="skip"; done ;;
    m) break ;;
    i[0-9]*)
      idx=$((${cmd:1} - 1))
      if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#SPEC_IDS[@]}" ]; then
        inspect "$idx"
      else
        echo -e "  ${RED}Invalid index.${RESET}"; sleep 1
      fi ;;
    [0-9]*)
      idx=$((cmd - 1))
      if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#SPEC_IDS[@]}" ]; then
        [ "${APPROVED[$idx]}" = "approve" ] && APPROVED[$idx]="skip" || APPROVED[$idx]="approve"
      else
        echo -e "  ${RED}Invalid index.${RESET}"; sleep 1
      fi ;;
  esac
done

# ─── Merge approved branches ─────────────────────────────────────
to_merge=()
for i in "${!APPROVED[@]}"; do
  [ "${APPROVED[$i]}" = "approve" ] && to_merge+=("${SPEC_BRANCHES[$i]}")
done

if [ ${#to_merge[@]} -eq 0 ]; then
  echo -e "\n  ${YELLOW}Nothing approved. Exit.${RESET}\n"
  exit 0
fi

merge_branch="feature/agent-merge-$(date +%Y%m%d-%H%M)"
read -rp "$(echo -e "\n  ${CYAN}Merge branch name [${merge_branch}]:${RESET} ")" mb
merge_branch="${mb:-$merge_branch}"

echo ""
git -C "$REPO_ROOT" checkout -b "$merge_branch" "$TARGET_BRANCH"
print_ok="echo -e '${GREEN}  ✓ ${RESET}'"

failed_merges=()
for branch in "${to_merge[@]}"; do
  echo -e "  ${DIM}Merging $branch...${RESET}"
  if git -C "$REPO_ROOT" merge --no-ff "$branch" -m "merge: $branch" 2>/dev/null; then
    echo -e "  ${GREEN}✓ $branch${RESET}"
  else
    echo -e "  ${RED}✗ $branch — conflict. Fix manually then continue.${RESET}"
    failed_merges+=("$branch")
    read -rp "$(echo -e "  ${CYAN}Resolve conflicts then press Enter...${RESET} ")" _
    git -C "$REPO_ROOT" add -A && git -C "$REPO_ROOT" merge --continue --no-edit 2>/dev/null || true
  fi
done

echo ""
echo -e "${BOLD}${GREEN}  ✓ Merge complete → ${merge_branch}${RESET}"
[ ${#failed_merges[@]} -gt 0 ] && echo -e "  ${YELLOW}⚠ Had conflicts: ${failed_merges[*]}${RESET}"
echo ""
echo -e "  ${DIM}Next: git push origin ${merge_branch} && open MR${RESET}"
echo ""
