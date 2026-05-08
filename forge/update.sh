#!/usr/bin/env bash
# Update forge installation — refreshes forge scripts and MCP server, preserves user content.
# User content preserved: .agent/overview.md, .agent/rules/
set -euo pipefail

REPO="namadnuno/ai"
BRANCH="main"
DEST=".agent"

RESET='\033[0m'; BOLD='\033[1m'; GREEN='\033[32m'; CYAN='\033[36m'; RED='\033[31m'

print_ok()  { echo -e "${GREEN}  ✓ $1${RESET}"; }
print_err() { echo -e "${RED}  ✗ $1${RESET}"; exit 1; }

echo ""
echo -e "${BOLD}${CYAN}  ⚒  Updating forge → .agent/${RESET}"
echo ""

git rev-parse --show-toplevel &>/dev/null || print_err "Not in a git repo. cd into your project first."
[ -d "$DEST" ] || print_err ".agent/ not found — run install.sh first."

REPO_ROOT="$(git rev-parse --show-toplevel)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Stash user-owned content before overwriting
mkdir -p "$TMP/preserve"
[ -f "$REPO_ROOT/.agent/overview.md" ] && cp "$REPO_ROOT/.agent/overview.md" "$TMP/preserve/overview.md"
[ -d "$REPO_ROOT/.agent/rules" ]       && cp -r "$REPO_ROOT/.agent/rules" "$TMP/preserve/rules"

echo -e "  Fetching latest from github.com/${REPO}..."
git clone --depth 1 --filter=blob:none --sparse \
  "https://github.com/${REPO}.git" "$TMP/repo" -b "$BRANCH" -q
git -C "$TMP/repo" sparse-checkout set forge

# Replace forge-owned files
rm -rf "$DEST"
cp -r "$TMP/repo/forge" "$DEST"
chmod +x "$DEST/run.sh" "$DEST/start.sh" "$DEST/review.sh" "$DEST/orchestrate.sh" "$DEST/analyze.sh" 2>/dev/null || true

# Restore user-owned content
mkdir -p "$REPO_ROOT/.agent/rules"
[ -f "$TMP/preserve/overview.md" ] && cp "$TMP/preserve/overview.md" "$REPO_ROOT/.agent/overview.md"
[ -d "$TMP/preserve/rules" ]       && cp -r "$TMP/preserve/rules/." "$REPO_ROOT/.agent/rules/"

print_ok "forge scripts updated"

# Upsert CLAUDE.local.md forge block with latest template
CLAUDE_LOCAL="$REPO_ROOT/CLAUDE.local.md"
STUB="$DEST/templates/claude-stub.template.md"
if [ ! -f "$CLAUDE_LOCAL" ]; then
  cp "$STUB" "$CLAUDE_LOCAL"
  print_ok "created CLAUDE.local.md with forge memory section"
elif grep -q 'forge:memory:start' "$CLAUDE_LOCAL" 2>/dev/null; then
  tmp_md="$(mktemp)"
  awk -v tpl="$STUB" '
    /<!-- forge:memory:start -->/ { in_block=1; while ((getline line < tpl) > 0) print line; close(tpl); next }
    /<!-- forge:memory:end -->/ { if (in_block) { in_block=0; next } }
    !in_block { print }
  ' "$CLAUDE_LOCAL" > "$tmp_md" && mv "$tmp_md" "$CLAUDE_LOCAL"
  print_ok "updated forge memory block in CLAUDE.local.md"
else
  printf '\n' >> "$CLAUDE_LOCAL"
  cat "$STUB" >> "$CLAUDE_LOCAL"
  print_ok "appended forge memory section to CLAUDE.local.md"
fi

# Update MCP server deps
if command -v npm &>/dev/null; then
  echo -e "  Updating MCP server deps..."
  (cd "$DEST/mcp" && npm install --silent --no-audit --no-fund) \
    && print_ok "MCP server ready" \
    || print_err "npm install failed in $DEST/mcp"
else
  print_err "npm required to update MCP server deps"
fi

print_ok "forge updated → .agent/"
echo ""
