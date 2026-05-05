#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
#  Colours
# ─────────────────────────────────────────────
RESET='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'
RED='\033[31m';  MAGENTA='\033[35m'; BLUE='\033[34m'

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

PROJECT_DOCKERFILE="$REPO_ROOT/.agent.Dockerfile"
PROJECT_BEST_PRACTICES="$REPO_ROOT/.agent.md"
PROJECT_CONFIG="$REPO_ROOT/.agent.config"

REPO_NAME="$(basename "$REPO_ROOT")"
IMAGE_NAME="agent-pipeline-$(echo "$REPO_NAME" | tr '[:upper:]' '[:lower:]'):latest"

SPECS_CONTENT=""
SPECS_SOURCE=""
BRANCH=""
CLAUDE_TMP=""
IMAGE_FILES=()
CLIP_TMP_DIR=""

# ─── Defaults (overridable in .agent.config) ───
TARGET_BRANCH="main"
PROGRAMMER_MAX_TURNS=15
REVIEWER_MAX_TURNS=10
ALLOW_REVIEWER_FIXES=true

# Per-agent models — pass anything Claude Code accepts
# ("sonnet", "opus", "haiku", or a full model id)
PROGRAMMER_MODEL="sonnet"
REVIEWER_MODEL="opus"

# Token budgets (input + output, per agent and total per run).
# 0 = no limit. Defaults sized for typical mid-feature work.
MAX_TOKENS_PROGRAMMER=500000
MAX_TOKENS_REVIEWER=300000
MAX_TOKENS_TOTAL=1000000

# Confirm before running if estimated max could exceed this fraction of total
WARN_AT_PERCENT=80

# ─────────────────────────────────────────────
#  Platform / package manager detection
# ─────────────────────────────────────────────
IS_MAC=false; IS_LINUX=false; IS_WAYLAND=false; IS_X11=false
PKG_MANAGER=""
if [[ "$OSTYPE" == "darwin"* ]]; then IS_MAC=true
else
  IS_LINUX=true
  [ -n "${WAYLAND_DISPLAY:-}" ] && IS_WAYLAND=true || true
  [ -n "${DISPLAY:-}" ]         && IS_X11=true     || true
fi
if $IS_LINUX; then
  if   command -v dnf  &>/dev/null; then PKG_MANAGER="dnf"
  elif command -v apt  &>/dev/null; then PKG_MANAGER="apt"
  elif command -v apt-get &>/dev/null; then PKG_MANAGER="apt-get"
  fi
fi

# ─────────────────────────────────────────────
print_header() {
  echo ""
  echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${CYAN}║         🤖  Agent Pipeline CLI           ║${RESET}"
  echo -e "${BOLD}${CYAN}║     Programmer → Reviewer → GitLab MR    ║${RESET}"
  echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════╝${RESET}"
  echo -e "${DIM}  project: ${REPO_NAME}${RESET}"
  echo ""
}
print_step()    { echo -e "\n${BOLD}${BLUE}▶ $1${RESET}"; }
print_ok()      { echo -e "${GREEN}  ✓ $1${RESET}"; }
print_warn()    { echo -e "${YELLOW}  ⚠ $1${RESET}"; }
print_error()   { echo -e "${RED}  ✗ $1${RESET}"; }
print_divider() { echo -e "${DIM}──────────────────────────────────────────${RESET}"; }

# Pretty number with thousand separators (works on mac+linux)
fmt_num() {
  printf "%'d" "$1" 2>/dev/null || echo "$1"
}

# ─────────────────────────────────────────────
#  First-run bootstrap
# ─────────────────────────────────────────────
bootstrap_project() {
  local needs=false
  [ ! -f "$PROJECT_DOCKERFILE" ] && needs=true
  [ ! -f "$PROJECT_BEST_PRACTICES" ] && needs=true
  if [[ "$needs" != true ]]; then return; fi

  print_step "First-time setup for this repository"
  echo ""

  [ ! -f "$PROJECT_DOCKERFILE" ] && {
    cp "$AGENT_DIR/templates/Dockerfile.template" "$PROJECT_DOCKERFILE"
    print_ok "Created $PROJECT_DOCKERFILE"
  }
  [ ! -f "$PROJECT_BEST_PRACTICES" ] && {
    cp "$AGENT_DIR/templates/best-practices.template.md" "$PROJECT_BEST_PRACTICES"
    print_ok "Created $PROJECT_BEST_PRACTICES"
  }

  echo ""
  echo -e "  ${BOLD}${YELLOW}Edit these for your project, then re-run.${RESET}"
  echo -e "  ${DIM}  • ${PROJECT_DOCKERFILE}${RESET}"
  echo -e "  ${DIM}  • ${PROJECT_BEST_PRACTICES}${RESET}"
  echo -e "  ${DIM}  • optional: copy templates/agent.config.template → ${PROJECT_CONFIG}${RESET}"
  echo ""
  exit 0
}

# ─────────────────────────────────────────────
load_project_config() {
  if [ -f "$PROJECT_CONFIG" ]; then
    # shellcheck disable=SC1090
    source "$PROJECT_CONFIG"
    print_ok "Loaded $PROJECT_CONFIG"
  fi
}

# ─────────────────────────────────────────────
ensure_image() {
  print_step "Docker sandbox image"
  echo -e "  ${DIM}Image: $IMAGE_NAME${RESET}"

  local needs_build=false
  if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
    needs_build=true
  else
    local image_created
    image_created=$(docker image inspect -f '{{.Created}}' "$IMAGE_NAME" \
      | xargs -I{} date -d {} +%s 2>/dev/null \
      || docker image inspect -f '{{.Created}}' "$IMAGE_NAME" \
      | xargs -I{} date -j -f "%Y-%m-%dT%H:%M:%S" {} +%s 2>/dev/null \
      || echo 0)
    local dockerfile_mtime
    dockerfile_mtime=$(stat -c %Y "$PROJECT_DOCKERFILE" 2>/dev/null \
                    || stat -f %m "$PROJECT_DOCKERFILE" 2>/dev/null \
                    || echo 0)
    [ "$dockerfile_mtime" -gt "$image_created" ] && {
      print_warn "Dockerfile changed — rebuilding"
      needs_build=true
    }
  fi

  if $needs_build; then
    echo -e "  ${DIM}Building (~1 min)...${RESET}"
    docker build -t "$IMAGE_NAME" -f "$PROJECT_DOCKERFILE" "$REPO_ROOT" --quiet \
      && print_ok "Built" \
      || { print_error "Build failed."; exit 1; }
  else
    print_ok "Up to date"
  fi
}

# ─────────────────────────────────────────────
#  Auto-install (condensed)
# ─────────────────────────────────────────────
ask_install() {
  echo ""; echo -e "  ${YELLOW}$1 not installed.${RESET}"
  echo -e "  ${DIM}Command: ${BOLD}$2${RESET}"
  read -rp "$(echo -e "  ${CYAN}Install? [Y/n]:${RESET} ")" yn
  [[ "$yn" == [Nn]* ]] && return 1 || return 0
}
pkg_install() {
  case "$PKG_MANAGER" in
    dnf)     sudo dnf install -y "$1" ;;
    apt)     sudo apt install -y "$1" ;;
    apt-get) sudo apt-get install -y "$1" ;;
    *) return 1 ;;
  esac
}

CLIP_TOOL=""
detect_or_install_clipboard() {
  if $IS_MAC; then CLIP_TOOL="osascript"; return; fi
  if $IS_WAYLAND; then
    if command -v wl-paste &>/dev/null; then CLIP_TOOL="wl-paste"
    elif ask_install "wl-clipboard" "sudo $PKG_MANAGER install wl-clipboard"; then
      pkg_install wl-clipboard && CLIP_TOOL="wl-paste"
    else CLIP_TOOL="none"; fi
    return
  fi
  if $IS_X11; then
    if command -v xclip &>/dev/null; then CLIP_TOOL="xclip"
    elif ask_install "xclip" "sudo $PKG_MANAGER install xclip"; then
      pkg_install xclip && CLIP_TOOL="xclip"
    else CLIP_TOOL="none"; fi
    return
  fi
  CLIP_TOOL="none"
}

check_deps() {
  print_step "Checking dependencies"
  command -v git &>/dev/null || {
    ask_install "git" "sudo $PKG_MANAGER install git" && pkg_install git || exit 1
  }
  print_ok "git"

  if ! command -v docker &>/dev/null; then
    print_error "Docker not installed."
    exit 1
  elif ! docker info &>/dev/null; then
    print_error "Docker not running."
    if ! $IS_MAC; then
      read -rp "$(echo -e "  ${CYAN}Start? [Y/n]:${RESET} ")" yn
      [[ "$yn" != [Nn]* ]] && sudo systemctl start docker
      docker info &>/dev/null || exit 1
    else exit 1; fi
  fi
  print_ok "docker"

  detect_or_install_clipboard
  [ "$CLIP_TOOL" != "none" ] && print_ok "clipboard: $CLIP_TOOL"
}

check_claude_auth() {
  print_step "Claude Code authentication"
  if [ ! -d "$HOME/.claude" ] || [ -z "$(ls -A "$HOME/.claude" 2>/dev/null)" ]; then
    if ! command -v claude &>/dev/null; then
      ask_install "Claude Code" "npm install -g @anthropic-ai/claude-code" \
        && npm install -g @anthropic-ai/claude-code || exit 1
    fi
    print_warn "Run 'claude' once to log in, then re-run."
    exit 1
  fi
  CLAUDE_TMP="$(mktemp -d /tmp/claude-cfg-XXXXXX)"
  # tar handles broken symlinks (e.g. debug/latest) that cp -r chokes on
  tar -C "$HOME/.claude" -cf - . 2>/dev/null | tar -C "$CLAUDE_TMP" -xf - 2>/dev/null || \
    cp -r "$HOME/.claude/." "$CLAUDE_TMP/" 2>/dev/null
  print_ok "Credentials ready"
}

# ─────────────────────────────────────────────
get_specs() {
  print_step "Specs"
  echo -e "  ${DIM}[1] Inline   [2] File path${RESET}\n"
  read -rp "$(echo -e "  ${CYAN}Option [1/2]:${RESET} ")" choice
  case "$choice" in
    2)
      read -rp "$(echo -e "  ${CYAN}File:${RESET} ")" f
      f="${f## }"; f="${f%% }"; f="${f//\'/}"; f="${f//\"/}"
      f="$(realpath "$f" 2>/dev/null || echo "$f")"
      [ -f "$f" ] || { print_error "Not found"; exit 1; }
      SPECS_CONTENT="$(cat "$f")"; SPECS_SOURCE="$f"
      print_ok "Loaded $(wc -l < "$f") lines"
      ;;
    *)
      echo -e "  ${DIM}Paste then ${BOLD}Ctrl+D${RESET}${DIM}:${RESET}\n"
      SPECS_CONTENT="$(cat)"; SPECS_SOURCE="inline"
      print_ok "Got $(echo "$SPECS_CONTENT" | wc -l) lines"
      ;;
  esac
  [ -n "$SPECS_CONTENT" ] || { print_error "Empty"; exit 1; }
}

clipboard_to_png() {
  local out="$1"
  case "$CLIP_TOOL" in
    osascript)
      local has
      has=$(osascript 2>/dev/null <<'EOF'
try
  set imgData to the clipboard as «class PNGf»
  return "yes"
on error
  return "no"
end try
EOF
      )
      [ "$has" != "yes" ] && { echo ""; return; }
      osascript 2>/dev/null <<EOF
set theFile to (open for access POSIX file "$out" with write permission)
write (the clipboard as «class PNGf») to theFile
close access theFile
EOF
      [ -s "$out" ] && echo "$out" || echo "" ;;
    wl-paste)
      if wl-paste --type image/png > "$out" 2>/dev/null && [ -s "$out" ]; then
        echo "$out"
      else
        local jpg="${out%.png}.jpg"
        wl-paste --type image/jpeg > "$jpg" 2>/dev/null && [ -s "$jpg" ] \
          && { rm -f "$out"; echo "$jpg"; } \
          || { rm -f "$out" "$jpg"; echo ""; }
      fi ;;
    xclip)
      xclip -selection clipboard -t image/png -o > "$out" 2>/dev/null && [ -s "$out" ] \
        && echo "$out" || { rm -f "$out"; echo ""; } ;;
    *) echo "" ;;
  esac
}

get_images() {
  print_step "Images  ${DIM}(optional)${RESET}\n"
  read -rp "$(echo -e "  ${CYAN}Add? [y/N]:${RESET} ")" want
  [[ "$want" != [Yy]* ]] && { echo -e "  ${DIM}Skipped.${RESET}"; return; }
  CLIP_TMP_DIR="$(mktemp -d /tmp/agent-imgs-XXXXXX)"
  local idx=1
  local clip_ok=true; [ "$CLIP_TOOL" = "none" ] && clip_ok=false
  echo ""
  $clip_ok && echo -e "  ${BOLD}c${RESET} clipboard  ${BOLD}f${RESET} file  ${BOLD}done${RESET}\n" \
           || echo -e "  ${BOLD}f${RESET} file  ${BOLD}done${RESET}\n"
  while true; do
    read -rp "$(echo -e "  ${CYAN}[c/f/done]:${RESET} ")" c
    local cl; cl="$(echo "$c" | tr '[:upper:]' '[:lower:]')"
    case "$cl" in
      [Cc]) $clip_ok || { print_warn "Not available"; continue; }
         local out="$CLIP_TMP_DIR/screenshot-${idx}.png"
         local s; s="$(clipboard_to_png "$out")"
         [ -z "$s" ] && print_warn "No image" \
                   || { IMAGE_FILES+=("$s"); print_ok "Saved: $(basename "$s")"; ((idx++)) || true; } ;;
      f) read -rp "$(echo -e "  ${CYAN}Path:${RESET} ")" p
         p="${p## }"; p="${p%% }"; p="${p//\'/}"; p="${p//\"/}"
         [ -z "$p" ] && continue
         eval "exp=($p)" 2>/dev/null || exp=("$p")
         for f in "${exp[@]}"; do
           f="$(realpath "$f" 2>/dev/null || echo "$f")"
           [ -f "$f" ] || { print_warn "Not found: $f"; continue; }
           local ext="${f##*.}"; ext="$(echo "$ext" | tr '[:upper:]' '[:lower:]')"
           case "$ext" in
             png|jpg|jpeg|gif|webp) IMAGE_FILES+=("$f"); print_ok "Added: $(basename "$f")" ;;
             *) print_warn "Unsupported: .$ext" ;;
           esac
         done ;;
      done|d|"") break ;;
    esac
  done
  [ ${#IMAGE_FILES[@]} -gt 0 ] && print_ok "${#IMAGE_FILES[@]} image(s)" \
                               || echo -e "  ${DIM}None.${RESET}"
}

get_branch() {
  print_step "Branch"
  local d="feature/agent-$(date +%Y%m%d-%H%M)"
  read -rp "$(echo -e "  ${CYAN}Branch ${DIM}[$d]:${RESET} ")" b
  BRANCH="${b:-$d}"; BRANCH="${BRANCH// /-}"; BRANCH="$(echo "$BRANCH" | tr '[:upper:]' '[:lower:]')"
  print_ok "Branch: $BRANCH"
}

# ─────────────────────────────────────────────
#  Confirmation summary including budgets
# ─────────────────────────────────────────────
confirm() {
  echo ""; print_divider
  echo -e "  ${BOLD}Summary${RESET}"
  print_divider
  echo -e "  ${DIM}Repo:${RESET}      $REPO_ROOT"
  echo -e "  ${DIM}Branch:${RESET}    ${BOLD}$BRANCH${RESET} → ${TARGET_BRANCH}"
  echo -e "  ${DIM}Specs:${RESET}     $SPECS_SOURCE"
  echo -e "  ${DIM}Images:${RESET}    ${#IMAGE_FILES[@]}"
  print_divider
  echo -e "  ${BOLD}Models${RESET}"
  echo -e "  ${DIM}Programmer:${RESET}  ${PROGRAMMER_MODEL}  ${DIM}(turns: $PROGRAMMER_MAX_TURNS)${RESET}"
  echo -e "  ${DIM}Reviewer:${RESET}    ${REVIEWER_MODEL}  ${DIM}(turns: $REVIEWER_MAX_TURNS)${RESET}"
  print_divider
  echo -e "  ${BOLD}Token budgets${RESET}"
  if [ "$MAX_TOKENS_PROGRAMMER" -gt 0 ]; then
    echo -e "  ${DIM}Programmer:${RESET}  $(fmt_num $MAX_TOKENS_PROGRAMMER) tokens"
  else
    echo -e "  ${DIM}Programmer:${RESET}  ${YELLOW}no limit${RESET}"
  fi
  if [ "$MAX_TOKENS_REVIEWER" -gt 0 ]; then
    echo -e "  ${DIM}Reviewer:${RESET}    $(fmt_num $MAX_TOKENS_REVIEWER) tokens"
  else
    echo -e "  ${DIM}Reviewer:${RESET}    ${YELLOW}no limit${RESET}"
  fi
  if [ "$MAX_TOKENS_TOTAL" -gt 0 ]; then
    echo -e "  ${DIM}Total run:${RESET}   $(fmt_num $MAX_TOKENS_TOTAL) tokens  ${DIM}(hard cap)${RESET}"
  else
    echo -e "  ${DIM}Total run:${RESET}   ${YELLOW}no limit${RESET}"
  fi
  print_divider; echo ""
  read -rp "$(echo -e "  ${CYAN}Run? [Y/n]:${RESET} ")" yn
  [[ "$yn" == [Nn]* ]] && { echo -e "${YELLOW}  Cancelled.${RESET}"; exit 0; }
}

# ─────────────────────────────────────────────
cleanup() {
  [ -n "$CLAUDE_TMP"   ] && rm -rf "$CLAUDE_TMP"
  [ -n "$CLIP_TMP_DIR" ] && rm -rf "$CLIP_TMP_DIR"
}
trap cleanup EXIT

# ─────────────────────────────────────────────
run_pipeline() {
  local specs_tmp; specs_tmp="$(mktemp /tmp/agent-specs-XXXXXX.md)"
  echo "$SPECS_CONTENT" > "$specs_tmp"

  local bp_tmp; bp_tmp="$(mktemp /tmp/agent-bp-XXXXXX.md)"
  [ -f "$PROJECT_BEST_PRACTICES" ] && cp "$PROJECT_BEST_PRACTICES" "$bp_tmp" \
                                   || echo "# (no project conventions defined)" > "$bp_tmp"

  local logs_dir="$REPO_ROOT/.agent.logs"
  mkdir -p "$logs_dir"
  rm -f "$logs_dir/.mr-url"

  local images_stage="" images_mount="" image_names_env=""
  if [ ${#IMAGE_FILES[@]} -gt 0 ]; then
    images_stage="$(mktemp -d /tmp/agent-stage-XXXXXX)"
    local names=()
    for f in "${IMAGE_FILES[@]}"; do
      local b="$(basename "$f")"; cp "$f" "$images_stage/$b"; names+=("$b")
    done
    images_mount="-v $images_stage:/agent/images:ro"
    image_names_env="$(IFS=:; echo "${names[*]}")"
  fi

  echo ""
  echo -e "${BOLD}${MAGENTA}  🚀 Starting...${RESET}\n"

  local ssh_mount=""; [ -d "$HOME/.ssh" ] && ssh_mount="-v $HOME/.ssh:/home/agent/.ssh:ro"
  local gitconfig_mount=""; [ -f "$HOME/.gitconfig" ] && gitconfig_mount="-v $HOME/.gitconfig:/home/agent/.gitconfig:ro"
  local claudejson_mount=""; [ -f "$HOME/.claude.json" ] && claudejson_mount="-v $HOME/.claude.json:/home/agent/.claude.json:ro"

  docker run --rm -it \
    -v "$REPO_ROOT:/workspace" \
    -v "$AGENT_DIR/prompts:/agent/prompts:ro" \
    -v "$AGENT_DIR/orchestrate.sh:/agent/orchestrate.sh:ro" \
    -v "$specs_tmp:/agent/specs.md:ro" \
    -v "$bp_tmp:/agent/best-practices.md:ro" \
    -v "$CLAUDE_TMP:/home/agent/.claude" \
    $images_mount $ssh_mount $gitconfig_mount $claudejson_mount \
    -e BRANCH="$BRANCH" \
    -e TARGET_BRANCH="$TARGET_BRANCH" \
    -e IMAGE_NAMES="${image_names_env:-}" \
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
    bash /agent/orchestrate.sh

  rm -f "$specs_tmp" "$bp_tmp"
  [ -n "$images_stage" ] && rm -rf "$images_stage"

  if [ -f "$logs_dir/.mr-url" ]; then
    local url; url="$(cat "$logs_dir/.mr-url")"
    echo ""
    echo -e "${BOLD}${GREEN}  ✓ Branch pushed!${RESET}"
    echo -e "  ${CYAN}${BOLD}${url}${RESET}\n"
    if   command -v xdg-open &>/dev/null; then xdg-open "$url"
    elif command -v open     &>/dev/null; then open     "$url"
    fi
  fi
}

# ─────────────────────────────────────────────
print_header
bootstrap_project
load_project_config
check_deps
check_claude_auth
ensure_image
get_specs
get_images
get_branch
confirm
run_pipeline
