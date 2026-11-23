# Generic fzf/MRU picker helpers, shared by claude-vercel's model picker and
# vercel-gateway-key's key picker. Kept free of model/key specifics: callers
# supply a "<id>\t<display>" TSV cache and an MRU file, and get back the
# chosen id on stdout.
#
# Meant to be `source`d (no shebang, no execution of its own).

# Most-recently-used list: the picked id moves to the top, capped at 8.
mru_record() {
  local file="$1" id="$2" tmp
  tmp="$(mktemp "$file.XXXXXX")"
  {
    printf '%s\n' "$id"
    if [[ -s "$file" ]]; then cat "$file"; fi
  } | awk -v keep=8 '$0 != "" && !seen[$0]++ { if (++kept <= keep) print }' >"$tmp"
  mv "$tmp" "$file"
}

# Lists <mru-file>'s rows of <cache> first (marked "*"), then the rest in
# cache order, and prints the chosen id. Exit status is fzf's: 0 on a
# selection, 130 on Esc/Ctrl-C.
mru_pick() {
  local file="$1" cache="$2" query="$3" prompt="$4" header="$5" mru=""
  if [[ -s "$file" ]]; then mru="$(cat "$file")"; fi
  awk -F'\t' -v mru="$mru" '
    BEGIN { ranks = split(mru, order, "\n"); for (i = 1; i <= ranks; i++) if (order[i] != "") rank[order[i]] = i }
    $1 in rank { r = rank[$1]; recent_id[r] = $1; recent_disp[r] = $2; next }
    { rest_id[++rest] = $1; rest_disp[rest] = $2 }
    END {
      for (i = 1; i <= ranks; i++) if (i in recent_id) print recent_id[i] "\t* " recent_disp[i]
      for (i = 1; i <= rest; i++) print rest_id[i] "\t  " rest_disp[i]
    }
  ' "$cache" |
    fzf --delimiter='\t' --with-nth=2 --accept-nth=1 --tiebreak=index \
      --height=60% --layout=reverse --border --prompt="$prompt" \
      --header="$header" --query="$query"
}
