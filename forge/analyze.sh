#!/usr/bin/env bash
# Forge analyze — v1: scaffold memory dirs + open editor.
# v2 will run AI pass to populate overview.md from codebase.
set -euo pipefail

RESET='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
GREEN='\033[32m'; CYAN='\033[36m'; YELLOW='\033[33m'

print_ok()   { echo -e "${GREEN}  ✓ $1${RESET}"; }
print_warn() { echo -e "${YELLOW}  ⚠ $1${RESET}"; }

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo ""
echo -e "${BOLD}${CYAN}  ⚒  Forge analyze${RESET}"
echo ""

mkdir -p "$REPO_ROOT/.agent/rules"
print_ok ".agent/rules/ ready"

if [ ! -f "$REPO_ROOT/.agent/overview.md" ]; then
  cp "$AGENT_DIR/templates/overview.template.md" "$REPO_ROOT/.agent/overview.md"
  print_ok "scaffolded .agent/overview.md from template"
else
  print_warn ".agent/overview.md exists — leaving alone"
fi

# Drop a starter rule template if rules dir is empty
if [ -z "$(ls -A "$REPO_ROOT/.agent/rules" 2>/dev/null)" ]; then
  cp "$AGENT_DIR/templates/rule.template.md" "$REPO_ROOT/.agent/rules/example.md"
  print_ok "wrote example rule .agent/rules/example.md"
fi

echo ""
echo -e "  ${BOLD}Next${RESET}"
echo -e "    ${DIM}1.${RESET} Edit ${BOLD}.agent/overview.md${RESET} — stack, entry points, dirs, conventions"
echo -e "    ${DIM}2.${RESET} Add rules in ${BOLD}.agent/rules/*.md${RESET} (frontmatter: name, description, globs)"
echo -e "    ${DIM}3.${RESET} Start a Claude session — MCP ${BOLD}forge${RESET} auto-connects via .mcp.json"
echo ""

if [ -n "${EDITOR:-}" ]; then
  read -rp "  Open .agent/overview.md in \$EDITOR now? [Y/n]: " yn
  [[ "$yn" != [Nn]* ]] && "$EDITOR" "$REPO_ROOT/.agent/overview.md"
fi
