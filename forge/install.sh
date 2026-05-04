#!/usr/bin/env bash
# Install forge into the current repo as .agent/
set -euo pipefail

REPO="namadnuno/ai"
BRANCH="main"
DEST=".agent"

RESET='\033[0m'; BOLD='\033[1m'; GREEN='\033[32m'; CYAN='\033[36m'; RED='\033[31m'

print_ok()  { echo -e "${GREEN}  ✓ $1${RESET}"; }
print_err() { echo -e "${RED}  ✗ $1${RESET}"; exit 1; }

echo ""
echo -e "${BOLD}${CYAN}  ⚒  Installing forge → .agent/${RESET}"
echo ""

# Must be in a git repo
git rev-parse --show-toplevel &>/dev/null || print_err "Not in a git repo. cd into your project first."

[ -d "$DEST" ] && {
  echo -e "  .agent/ already exists."
  read -rp "  Overwrite? [y/N]: " yn
  [[ "${yn,,}" == "y"* ]] || { echo "  Cancelled."; exit 0; }
  rm -rf "$DEST"
}

# Download via git sparse-checkout (no full clone)
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo -e "  Fetching from github.com/${REPO}..."
git clone --depth 1 --filter=blob:none --sparse \
  "https://github.com/${REPO}.git" "$TMP" -b "$BRANCH" -q
git -C "$TMP" sparse-checkout set forge

cp -r "$TMP/forge" "$DEST"
chmod +x "$DEST/run.sh" "$DEST/start.sh" "$DEST/review.sh" "$DEST/orchestrate.sh" 2>/dev/null || true

print_ok "forge installed → .agent/"
echo ""
echo -e "  ${BOLD}Next:${RESET}"
echo -e "    ./.agent/run.sh       — interactive single-agent run"
echo -e "    ./.agent/start.sh     — AFK queue runner (after /grill-agents)"
echo -e "    ./.agent/review.sh    — inspect + merge agent branches"
echo ""
