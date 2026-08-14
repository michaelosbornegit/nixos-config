#!/usr/bin/env bash
# Diagnose the Ghostty state tint end to end. Prints one line per check and
# exits 1 if anything is broken, so it can be used as a gate.
#
# Run it from inside the Ghostty session you want to diagnose -- several checks
# depend on the environment and tty of the calling process.
#
# The functional check leaves the background in the "working" tint. That is the
# correct state while an agent is mid-turn; the Stop hook restores "idle" when
# the turn ends.

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SCRIPT="$CLAUDE_DIR/ghostty-bg"
CONF="$CLAUDE_DIR/ghostty-bg.conf"
SETTINGS="$CLAUDE_DIR/settings.json"
HOOKS_JSON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../references" && pwd)/hooks.json"

fails=0
pass() { printf '  PASS  %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
note() { printf '  NOTE  %s\n' "$1"; }

echo "== environment =="
case "$TERM_PROGRAM|$TERM|$GHOSTTY_RESOURCES_DIR" in
  *ghostty*|*Ghostty*) pass "running under Ghostty" ;;
  *) note "not Ghostty (TERM_PROGRAM=${TERM_PROGRAM:-unset} TERM=${TERM:-unset}) -- the tint no-ops here by design" ;;
esac
if [ -n "$TMUX$ZELLIJ$ZELLIJ_SESSION_NAME$STY" ]; then
  note "inside a multiplexer -- the tint no-ops by design (it would tint the whole window, not the pane)"
fi
[ -f "$CLAUDE_DIR/no-bg-tint" ] && note "off switch present ($CLAUDE_DIR/no-bg-tint) -- tinting is disabled on purpose"

echo "== files =="
if [ -e "$SCRIPT" ]; then
  pass "script present: $SCRIPT"
  [ -L "$SCRIPT" ] && { t=$(readlink "$SCRIPT"); [ -e "$SCRIPT" ] && pass "symlink resolves -> $t" || fail "DANGLING symlink -> $t (is the nix-config repo cloned at the expected path?)"; }
  [ -x "$SCRIPT" ] && pass "script is executable" || fail "script is NOT executable (hooks exec it directly; chmod +x the repo file)"
else
  fail "script missing: $SCRIPT"
fi
[ -e "$CONF" ] && pass "conf present: $CONF" || note "conf missing -- the script falls back to its built-in colours, which is fine"

echo "== hooks in settings.json =="
if [ ! -f "$SETTINGS" ]; then
  fail "no settings.json at $SETTINGS"
elif ! jq -e . "$SETTINGS" > /dev/null 2>&1; then
  fail "settings.json is not valid JSON -- fix that before merging anything"
else
  for ev in $(jq -r 'keys_unsorted[]' "$HOOKS_JSON"); do
    if jq -e --arg e "$ev" '[.hooks[$e][]?.hooks[]?.command // ""] | any(test("ghostty-bg"))' "$SETTINGS" > /dev/null 2>&1; then
      pass "$ev wired"
    else
      fail "$ev NOT wired"
    fi
  done
  stale=$(jq -r '[.hooks[]?[]?.hooks[]?.command // "" | select(test("ghostty-bg")) | select(test("\\$HOME") | not)] | length' "$SETTINGS")
  [ "$stale" -gt 0 ] && fail "$stale hook command(s) use an absolute path instead of \$HOME -- not portable across machines" \
                     || pass "all hook commands are \$HOME-relative"
fi

echo "== functional =="
if [ -x "$SCRIPT" ]; then
  log="$CLAUDE_DIR/ghostty-bg.log"
  touch "$CLAUDE_DIR/ghostty-bg.debug"
  : > "$log"
  "$SCRIPT" working
  if [ -s "$log" ]; then
    line=$(cat "$log")
    case "$line" in
      *NO-TTY*) fail "ran but could not resolve a tty: $line" ;;
      *) pass "wrote OSC 11: $line" ;;
    esac
  else
    note "produced no log line -- expected if a guard above intentionally disabled it"
  fi
  rm -f "$CLAUDE_DIR/ghostty-bg.debug" "$log"
fi

echo
[ "$fails" -eq 0 ] && echo "all checks passed" || echo "$fails check(s) failed"
exit $((fails > 0))
