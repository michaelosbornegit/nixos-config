label="$1"
expr="$2"

if [[ "${LAZY_NIX_BUILD_FORCE_GUI:-0}" != 1 ]] && {
  [[ -t 2 ]] || { [[ -z "${DISPLAY:-}" ]] && [[ -z "${WAYLAND_DISPLAY:-}" ]]; };
}; then
  exec nix build --impure --no-link --print-out-paths --expr "$expr"
fi

tmpdir="$(mktemp -d)"
updates="$tmpdir/progress"
result_file="$tmpdir/result"
log_pipe="$tmpdir/nix-stderr"
done_file="$tmpdir/done"
: > "$updates"
mkfifo "$log_pipe"

cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

printf '# Preparing %s\n0\n' "$label" >> "$updates"

(
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [[ -e "$done_file" ]] && exit 0
    sleep 0.1
  done

  if [[ ! -e "$done_file" ]]; then
    tail -n +1 -f "$updates" | zenity \
      --progress \
      --title="Preparing $label" \
      --text="Preparing $label" \
      --percentage=0 \
      --auto-close \
      --no-cancel \
      --width=460 \
      >/dev/null 2>&1
  fi
) &
viewer_pid="$!"

gawk -v label="$label" '
function human(bytes, unit, value) {
  value = bytes + 0
  split("B KiB MiB GiB TiB", unit)
  for (i = 1; i < 5 && value >= 1024; i++) {
    value = value / 1024
  }
  if (i == 1) {
    return sprintf("%d %s", value, unit[i])
  }
  return sprintf("%.1f %s", value, unit[i])
}

function emit(force, active_id, download_current, copy_current, download_known, copy_known, completed, expected, percent, text, now) {
  download_current = completed_download
  copy_current = completed_copy
  download_known = expected_download
  copy_known = expected_copy

  for (active_id in download_done) {
    download_current += download_done[active_id]
    if (expected_download == 0) {
      download_known += download_total[active_id]
    }
  }

  for (active_id in copy_done) {
    copy_current += copy_done[active_id]
    if (expected_copy == 0) {
      copy_known += copy_total[active_id]
    }
  }

  completed = download_current + copy_current
  expected = download_known + copy_known
  percent = expected > 0 ? int(completed * 100 / expected) : 0
  if (percent > 99) {
    percent = 99
  }

  if (download_known > 0 && download_current < download_known) {
    text = "Downloading " human(download_current) " / " human(download_known) " for " label
  } else if (copy_known > 0 && copy_current < copy_known) {
    text = "Installing " human(copy_current) " / " human(copy_known) " for " label
  } else if (expected > 0) {
    text = "Finishing " label
  } else {
    text = "Preparing " label
  }

  now = systime()
  if (force || now > last_emit) {
    printf "# %s\n%s\n", text, percent
    fflush()
    last_emit = now
    last_percent = percent
    last_text = text
  }
}

/^@nix / {
  action = type = id = ""
  if (match($0, /"action":"[^"]+"/)) {
    action = substr($0, RSTART + 10, RLENGTH - 11)
  } else {
    next
  }
  if (match($0, /"type":[0-9]+/)) {
    type = substr($0, RSTART + 7, RLENGTH - 7)
  }
  if (match($0, /"id":[0-9]+/)) {
    id = substr($0, RSTART + 5, RLENGTH - 5)
  }

  if (action == "start" && type == "101" && id != "") {
    activity_kind[id] = "download"
    emit(0)
  } else if (action == "start" && type == "100" && id != "") {
    activity_kind[id] = "copy"
    emit(0)
  } else if (action == "result" && type == "106" && match($0, /"fields":\[[0-9]+,[0-9]+\]/)) {
    fields = substr($0, RSTART + 10, RLENGTH - 11)
    split(fields, parts, ",")
    code = parts[1]
    value = parts[2] + 0
    if (code == "101" && value > expected_download) {
      expected_download = value
    } else if (code == "100" && value > expected_copy) {
      expected_copy = value
    }
    emit(0)
  } else if (action == "result" && type == "105" && id != "" && id in activity_kind && match($0, /"fields":\[[0-9]+,[0-9]+,/)) {
    fields = substr($0, RSTART + 10, RLENGTH - 11)
    split(fields, parts, ",")
    current = parts[1] + 0
    total = parts[2] + 0
    if (activity_kind[id] == "download") {
      download_done[id] = current
      download_total[id] = total
    } else {
      copy_done[id] = current
      copy_total[id] = total
    }
    emit(0)
  } else if (action == "stop" && id != "" && id in activity_kind) {
    if (activity_kind[id] == "download") {
      total = id in download_total ? download_total[id] : download_done[id]
      completed_download += total
      delete download_done[id]
      delete download_total[id]
    } else {
      total = id in copy_total ? copy_total[id] : copy_done[id]
      completed_copy += total
      delete copy_done[id]
      delete copy_total[id]
    }
    delete activity_kind[id]
    emit(0)
  }
}

END {
  emit(1)
}
' < "$log_pipe" >> "$updates" &
parser_pid="$!"

if nix build --impure --no-link --print-out-paths --log-format internal-json --expr "$expr" \
  > "$result_file" \
  2> "$log_pipe"; then
  status=0
else
  status="$?"
fi

wait "$parser_pid" 2>/dev/null || true

touch "$done_file"
printf '# Launching %s\n100\n' "$label" >> "$updates"
wait "$viewer_pid" 2>/dev/null || true

if [[ "$status" != 0 ]]; then
  zenity \
    --error \
    --title="Failed to prepare $label" \
    --text="Could not prepare $label. Run this launcher from a terminal for the full Nix output." \
    --width=520 2>/dev/null || true
  exit "$status"
fi

tail -n 1 "$result_file"
