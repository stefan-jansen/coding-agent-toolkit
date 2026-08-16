#!/usr/bin/env bash
# resolve-session.sh — map a Claude Code session to its on-disk artifacts:
# the transcript JSONL (raw conversation log) and its latest transition file.
#
# You cannot inspect a peer's live context through messaging (a message is
# plain text, not context). This resolves the two readable artifacts a session
# leaves on disk so you CAN inspect what it has been doing, out of band.
#
# Input — identify the target session one of three ways (from a ListAgents row):
#   --pane %ID     tmux pane id shown in the row's `location` (e.g. %177)
#   --pid  PID     the session's claude process id, if you know it
#   --cwd  PATH    the session's working directory (for bg sessions w/o a pane)
# Output selectors (default: both):
#   --transcript   only the transcript JSONL
#   --transition   only the latest transition file
#   --tail N       include the last N user messages / transition head (default 5)
#
# Limitations: a background (`bg`) session has no tmux pane — resolve it with
# --cwd. When several sessions share one cwd, the newest transcript wins; pass
# --pid to be exact. Reads only; never writes.
set -euo pipefail

MODE=both PANE= PID= CWD= TAIL=5
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pane) PANE="$2"; shift 2;;
    --pid)  PID="$2";  shift 2;;
    --cwd)  CWD="$2";  shift 2;;
    --transcript) MODE=transcript; shift;;
    --transition) MODE=transition; shift;;
    --tail) TAIL="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

# --- find the claude PID under a tmux pane (descend the process tree) ---
claude_pid_under() {
  local root="$1" found=
  local stack=("$root")
  while [[ ${#stack[@]} -gt 0 ]]; do
    local p="${stack[-1]}"; unset 'stack[-1]'
    [[ "$(ps -o comm= -p "$p" 2>/dev/null)" == "claude" ]] && { echo "$p"; return 0; }
    for c in $(pgrep -P "$p" 2>/dev/null || true); do stack+=("$c"); done
  done
  return 1
}

# --- resolve cwd (and PID when available) ---
if [[ -n "$PANE" ]]; then
  shell_pid="$(tmux display -pt "$PANE" '#{pane_pid}' 2>/dev/null || true)"
  [[ -z "$shell_pid" ]] && { echo "no tmux pane $PANE" >&2; exit 1; }
  PID="$(claude_pid_under "$shell_pid" || true)"
  [[ -z "$PID" ]] && { echo "no claude process under pane $PANE" >&2; exit 1; }
fi
if [[ -n "$PID" && -z "$CWD" ]]; then
  CWD="$(readlink "/proc/$PID/cwd" 2>/dev/null || true)"
fi
[[ -z "$CWD" ]] && { echo "could not resolve a working directory; pass --cwd" >&2; exit 1; }
CWD="${CWD%/}"

echo "session cwd : $CWD"
[[ -n "$PID" ]] && echo "claude pid  : $PID"

# --- locate the project transcript directory ---
enc="-$(printf '%s' "${CWD#/}" | sed 's#/#-#g; s#\.#-#g')"
PROJ="$HOME/.claude/projects/$enc"
if [[ ! -d "$PROJ" ]]; then
  # fall back: scan for a project dir whose newest transcript records this cwd
  PROJ=
  for d in "$HOME"/.claude/projects/*/; do
    nf="$(ls -t "$d"*.jsonl 2>/dev/null | head -1 || true)"
    [[ -z "$nf" ]] && continue
    if grep -qm1 "\"cwd\":\"$CWD\"" "$nf" 2>/dev/null; then PROJ="${d%/}"; break; fi
  done
fi

if [[ "$MODE" == both || "$MODE" == transcript ]]; then
  echo "--- transcript ---"
  if [[ -n "$PROJ" && -d "$PROJ" ]]; then
    TS="$(ls -t "$PROJ"/*.jsonl 2>/dev/null | head -1 || true)"
    if [[ -n "$TS" ]]; then
      echo "path   : $TS"
      echo "session: $(basename "$TS" .jsonl)"
      echo "size   : $(du -h "$TS" | cut -f1)   modified: $(date -r "$TS" '+%Y-%m-%d %H:%M:%S')"
      echo "last $TAIL user messages:"
      python3 - "$TS" "$TAIL" <<'PY' 2>/dev/null || echo "  (could not parse)"
import json, sys
path, n = sys.argv[1], int(sys.argv[2])
msgs = []
with open(path, encoding="utf-8") as fh:
    for line in fh:
        try:
            d = json.loads(line)
        except Exception:
            continue
        if d.get("type") != "user":
            continue
        c = d.get("message", {}).get("content", "")
        if isinstance(c, list):
            c = " ".join(b.get("text", "") for b in c if isinstance(b, dict) and b.get("type") == "text")
        c = " ".join(str(c).split())
        if c:
            msgs.append(c)
for m in msgs[-n:]:
    print("  • " + (m[:200] + ("…" if len(m) > 200 else "")))
PY
    else
      echo "  (no transcript found in $PROJ)"
    fi
  else
    echo "  (no project transcript dir for $CWD)"
  fi
fi

if [[ "$MODE" == both || "$MODE" == transition ]]; then
  echo "--- latest transition ---"
  latest=
  for base in "$CWD/.workspace/transitions" "$CWD/.claude/transitions"; do
    [[ -d "$base" ]] || continue
    cand="$(ls -t "$base"/*/*.md 2>/dev/null | head -1 || true)"
    [[ -n "$cand" ]] && { latest="$cand"; break; }
  done
  if [[ -n "$latest" ]]; then
    echo "path : $latest"
    echo "modified: $(date -r "$latest" '+%Y-%m-%d %H:%M:%S')"
    echo "head:"
    sed -n '1,'"$((TAIL+4))"'p' "$latest" | sed 's/^/  /'
  else
    echo "  (no transition files under $CWD/.workspace/transitions)"
  fi
fi
