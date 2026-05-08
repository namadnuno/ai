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
chmod +x "$DEST/run.sh" "$DEST/start.sh" "$DEST/review.sh" "$DEST/orchestrate.sh" "$DEST/analyze.sh" 2>/dev/null || true

# Hide from git locally — no .gitignore change, no repo trace
EXCLUDE="$(git rev-parse --git-dir)/info/exclude"
mkdir -p "$(dirname "$EXCLUDE")"
grep -qxF '.agent/' "$EXCLUDE" 2>/dev/null || echo '.agent/' >> "$EXCLUDE"
grep -qxF '.agent.queue/' "$EXCLUDE" 2>/dev/null || echo '.agent.queue/' >> "$EXCLUDE"
grep -qxF '.agent.logs/' "$EXCLUDE" 2>/dev/null || echo '.agent.logs/' >> "$EXCLUDE"
grep -qxF '.agent.Dockerfile' "$EXCLUDE" 2>/dev/null || echo '.agent.Dockerfile' >> "$EXCLUDE"
grep -qxF '.agent.md' "$EXCLUDE" 2>/dev/null || echo '.agent.md' >> "$EXCLUDE"
grep -qxF '.agent.config' "$EXCLUDE" 2>/dev/null || echo '.agent.config' >> "$EXCLUDE"
grep -qxF '.mcp.json' "$EXCLUDE" 2>/dev/null || echo '.mcp.json' >> "$EXCLUDE"
grep -qxF 'CLAUDE.local.md' "$EXCLUDE" 2>/dev/null || echo 'CLAUDE.local.md' >> "$EXCLUDE"

# ─── Memory layer scaffold ──────────────────────────────────────────
REPO_ROOT="$(git rev-parse --show-toplevel)"

# Rules dir + overview (only if missing — never overwrite user content)
mkdir -p "$REPO_ROOT/.agent/rules"
[ -f "$REPO_ROOT/.agent/overview.md" ] || \
  cp "$DEST/templates/overview.template.md" "$REPO_ROOT/.agent/overview.md"

# .mcp.json — absolute paths (Claude resolves args relative to shell cwd, not project root)
MCP_JSON="$REPO_ROOT/.mcp.json"
SERVER_ABS="$REPO_ROOT/.agent/mcp/server.js"
FORGE_ENTRY=$(cat <<EOF_FORGE
{"command":"node","args":["$SERVER_ABS"],"env":{"FORGE_ROOT":"$REPO_ROOT"}}
EOF_FORGE
)
if [ -f "$MCP_JSON" ]; then
  if command -v jq &>/dev/null; then
    tmp="$(mktemp)"
    jq --argjson forge "$FORGE_ENTRY" '.mcpServers.forge = $forge' \
      "$MCP_JSON" > "$tmp" && mv "$tmp" "$MCP_JSON"
    print_ok "merged forge entry into existing .mcp.json"
  else
    print_err "jq required to merge into existing .mcp.json — install jq and re-run"
  fi
else
  jq -n --argjson forge "$FORGE_ENTRY" '{mcpServers:{forge:$forge}}' > "$MCP_JSON" 2>/dev/null \
    || cat > "$MCP_JSON" <<EOF_MCP
{
  "mcpServers": {
    "forge": $FORGE_ENTRY
  }
}
EOF_MCP
  print_ok "wrote .mcp.json"
fi

# CLAUDE.local.md stub — user-local, gitignored, append once idempotent via marker
CLAUDE_LOCAL="$REPO_ROOT/CLAUDE.local.md"
if [ -f "$CLAUDE_LOCAL" ]; then
  if ! grep -q 'forge:memory:start' "$CLAUDE_LOCAL" 2>/dev/null; then
    printf '\n' >> "$CLAUDE_LOCAL"
    cat "$DEST/templates/claude-stub.template.md" >> "$CLAUDE_LOCAL"
    print_ok "appended forge memory section to CLAUDE.local.md"
  fi
else
  cp "$DEST/templates/claude-stub.template.md" "$CLAUDE_LOCAL"
  print_ok "created CLAUDE.local.md with forge memory section"
fi

# Ensure CLAUDE.local.md is gitignored
GITIGNORE="$REPO_ROOT/.gitignore"
if [ -f "$GITIGNORE" ]; then
  grep -qxF 'CLAUDE.local.md' "$GITIGNORE" 2>/dev/null || { echo 'CLAUDE.local.md' >> "$GITIGNORE"; print_ok "added CLAUDE.local.md to .gitignore"; }
else
  echo 'CLAUDE.local.md' > "$GITIGNORE"
  print_ok "created .gitignore with CLAUDE.local.md"
fi

# Install MCP server deps
if command -v npm &>/dev/null; then
  echo -e "  Installing MCP server deps..."
  (cd "$DEST/mcp" && npm install --silent --no-audit --no-fund) \
    && print_ok "MCP server ready" \
    || print_err "npm install failed in $DEST/mcp"
else
  print_err "npm required to install MCP server deps"
fi

print_ok "forge installed → .agent/"
print_ok "hidden from git via .git/info/exclude (no .gitignore changes)"
echo ""
echo -e "  ${BOLD}Next:${RESET}"
echo -e "    \$EDITOR .agent/overview.md     — fill in repo picture (load-bearing for memory)"
echo -e "    ./.agent/analyze.sh            — scaffold rules + open editor"
echo -e "    ./.agent/run.sh                — interactive single-agent run"
echo -e "    ./.agent/start.sh              — AFK queue runner"
echo -e "    ./.agent/review.sh             — inspect + merge agent branches"
echo ""
