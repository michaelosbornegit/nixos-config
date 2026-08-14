#!/usr/bin/env bash
# Idempotently merge the tint hook entries into a Claude Code settings.json.
#
#   install-hooks.sh [path-to-settings.json]      # default: ~/.claude/settings.json
#   DRY_RUN=1 install-hooks.sh                    # print the result, write nothing
#
# Safe to run repeatedly. For each event it removes any existing ghostty-bg hook
# and re-adds the canonical one, so a stale entry (e.g. an absolute /Users/...
# path from another machine) is repaired rather than duplicated. Hooks belonging
# to anything else -- notably a sound/flash hook on Stop -- are left untouched,
# which is why this merges per-event instead of assigning .hooks wholesale.

set -euo pipefail

SETTINGS="${1:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json}"
HOOKS_JSON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../references" && pwd)/hooks.json"

command -v jq > /dev/null || { echo "jq is required (nix-shell -p jq)" >&2; exit 1; }
[ -f "$HOOKS_JSON" ] || { echo "missing canonical hooks: $HOOKS_JSON" >&2; exit 1; }

if [ ! -f "$SETTINGS" ]; then
  mkdir -p "$(dirname "$SETTINGS")"
  echo '{}' > "$SETTINGS"
  echo "created $SETTINGS"
fi

jq -e . "$SETTINGS" > /dev/null 2>&1 || {
  echo "refusing to touch $SETTINGS -- it is not valid JSON. Fix it first." >&2
  exit 1
}

merged=$(jq --slurpfile desired "$HOOKS_JSON" '
  ($desired[0]) as $d
  | .hooks = (.hooks // {})
  | reduce ($d | keys_unsorted[]) as $e (.;
      .hooks[$e] = (
        (
          ((.hooks[$e] // [])
            | map(.hooks = ((.hooks // []) | map(select((.command // "") | test("ghostty-bg") | not))))
            | map(select((.hooks | length) > 0)))
        ) as $kept
        | (if ($kept | length) == 0 then [{matcher: "", hooks: []}] else $kept end)
        | .[0].hooks += [$d[$e]]
      )
    )
' "$SETTINGS")

echo "$merged" | jq -e . > /dev/null || { echo "merge produced invalid JSON, aborting" >&2; exit 1; }

if [ "${DRY_RUN:-}" = "1" ]; then
  echo "$merged"
  exit 0
fi

if [ "$(echo "$merged" | jq -S .)" = "$(jq -S . "$SETTINGS")" ]; then
  echo "already up to date, no changes written"
  exit 0
fi

cp "$SETTINGS" "$SETTINGS.tint-bak"
printf '%s\n' "$merged" > "$SETTINGS"
echo "merged tint hooks into $SETTINGS (previous version saved as $(basename "$SETTINGS").tint-bak)"
jq -r '.hooks | to_entries[] | "  \(.key): \(.value[0].hooks | map(.command) | join("  |  "))"' "$SETTINGS"
