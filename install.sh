#!/usr/bin/env bash
#
# coding-agent-toolkit installer (run once per machine)
#
# Registers the coding-agent-plugins marketplace and enables the core plugins at
# USER level (~/.claude/settings.json). After this, the workflow (/align, /plan,
# /plan-issues, /next-issue, /ship, /handoff, /continue) and project bootstrap
# (/setup) are available in EVERY project — including brand-new empty folders,
# with no per-project setup. That is what dissolves the chicken-and-egg: the
# commands come from your user config, so a fresh folder already has them.
#
# What it does:
#   1. Finds an existing coding-agent-plugins marketplace, or clones one.
#   2. Merges (never clobbers) ~/.claude/settings.json: registers the marketplace
#      and enables the core plugins globally. A timestamped backup is written first.
#   3. (optional) Symlinks the Codex prompt mirror into ~/.codex/prompts/.
#
# Idempotent: safe to re-run.
#
# Usage:
#   ./install.sh [--plugins-dir DIR] [--with-codex|--no-codex] [--help]
#
# Env overrides: PLUGINS_DIR, CLAUDE_SETTINGS
set -euo pipefail

PLUGINS_REPO="https://github.com/stefan-jansen/coding-agent-plugins.git"
CLAUDE_SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
PLUGINS_DIR="${PLUGINS_DIR:-}"
CORE_PLUGINS=(setup workflow transition memory)   # enabled globally
WITH_CODEX="auto"                                 # auto | yes | no
TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
info() { printf '\033[36m›\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m✓\033[0m %s\n' "$*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --plugins-dir) PLUGINS_DIR="$2"; shift 2;;
    --with-codex)  WITH_CODEX="yes"; shift;;
    --no-codex)    WITH_CODEX="no"; shift;;
    -h|--help)     sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *)             die "unknown argument: $1 (see --help)";;
  esac
done

# --- 0. dependencies ---------------------------------------------------------
command -v git >/dev/null 2>&1 || die "git is required"
command -v jq  >/dev/null 2>&1 || die "jq is required (macOS: brew install jq · Debian/Ubuntu: apt install jq)"

# --- 1. locate or clone the marketplace --------------------------------------
if [ -z "$PLUGINS_DIR" ]; then
  for c in "$HOME/agents/coding/plugins" "$TOOLKIT_DIR/../coding-agent-plugins" "$HOME/.coding-agent/plugins"; do
    if [ -f "$c/.claude-plugin/marketplace.json" ]; then PLUGINS_DIR="$(cd "$c" && pwd)"; break; fi
  done
fi

if [ -z "$PLUGINS_DIR" ]; then
  PLUGINS_DIR="$HOME/.coding-agent/plugins"
  info "cloning coding-agent-plugins → $PLUGINS_DIR"
  git clone --depth 1 "$PLUGINS_REPO" "$PLUGINS_DIR"
else
  info "using existing marketplace at $PLUGINS_DIR"
fi
[ -f "$PLUGINS_DIR/.claude-plugin/marketplace.json" ] || die "no marketplace.json under $PLUGINS_DIR"
ok "marketplace: $PLUGINS_DIR"

# --- 2. merge ~/.claude/settings.json (non-destructive) ----------------------
mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
[ -f "$CLAUDE_SETTINGS" ] || echo '{}' > "$CLAUDE_SETTINGS"
jq empty "$CLAUDE_SETTINGS" 2>/dev/null || die "$CLAUDE_SETTINGS is not valid JSON; fix or move it first"
BACKUP="$CLAUDE_SETTINGS.bak-$(date +%Y%m%d%H%M%S)"
cp "$CLAUDE_SETTINGS" "$BACKUP"

PLUGINS_JSON="$(printf '%s\n' "${CORE_PLUGINS[@]}" | jq -R '. + "@local"' | jq -s '.')"
jq --arg dir "$PLUGINS_DIR" --argjson plugins "$PLUGINS_JSON" '
  .extraKnownMarketplaces = (.extraKnownMarketplaces // {})
  | .extraKnownMarketplaces.local = { source: { source: "directory", path: $dir } }
  | .enabledPlugins = ((.enabledPlugins // {}) + (reduce $plugins[] as $p ({}; .[$p] = true)))
' "$CLAUDE_SETTINGS" > "$CLAUDE_SETTINGS.tmp" && mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
ok "wrote $CLAUDE_SETTINGS (backup: $BACKUP)"
info "enabled globally: ${CORE_PLUGINS[*]}"

# --- 3. Codex prompt mirror (optional) ---------------------------------------
if [ "$WITH_CODEX" = "yes" ] || { [ "$WITH_CODEX" = "auto" ] && [ -d "$HOME/.codex" ]; }; then
  if [ -d "$TOOLKIT_DIR/codex/prompts" ]; then
    mkdir -p "$HOME/.codex/prompts"
    for f in "$TOOLKIT_DIR"/codex/prompts/*.md; do
      ln -sf "$f" "$HOME/.codex/prompts/$(basename "$f")"
    done
    ok "linked Codex prompts → ~/.codex/prompts/"
  fi
elif [ "$WITH_CODEX" = "auto" ]; then
  info "skipped Codex prompts (~/.codex not found; re-run with --with-codex to force)"
fi

# --- 4. verify + next steps --------------------------------------------------
echo
ok "System is set up. In any project — new or existing — you now have:"
echo "    /setup      bootstrap this folder (.workspace/ + AGENTS.md), interview-driven"
echo "    /align      pin down what 'done' means for a piece of work"
echo "    /plan · /plan-issues · /next-issue · /ship    spec → issues → PR"
echo "    /handoff · /continue    carry context across sessions and hosts"
echo
echo "  Next: cd into a project and run /setup (or /setup:user once for global agent instructions)."
echo "  Codex users: your prompts live in ~/.codex/prompts/ (or point Codex at $TOOLKIT_DIR/codex/prompts/)."
