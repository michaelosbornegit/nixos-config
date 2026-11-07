# Launches the newest Claude Desktop build right away, then checks Anthropic's
# apt repo in a detached worker and builds any newer release for next launch.
#
# Everything read from the network is untrusted until verified:
#   InRelease  -> gpgv against the Anthropic key committed in this repo
#   Packages   -> fetched by the SHA256 the signed InRelease lists, re-checked
#   .deb       -> fixed-output fetchurl with the SHA256 from that Packages file
# Version and hash are pattern-checked and passed with --argstr, and the
# download URL is built from a fixed prefix, never taken from the index.
#
# Env (set by default.nix): PINNED_PACKAGE PINNED_VERSION UPDATE_EXPR KEYRING
# DEB_ARCH. Set CLAUDE_DESKTOP_AUTO_UPDATE=0 to skip the update check.

repo="https://downloads.claude.ai/claude-desktop/apt/stable"
state="${XDG_STATE_HOME:-$HOME/.local/state}/claude-desktop"
versions="$state/versions"
log="$state/update.log"
check_interval=900

mkdir -p "$versions"

version_gt() {
  [[ "$1" != "$2" ]] && [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n 1)" == "$1" ]]
}

# Sets newest_version and newest_path to the newest working build, falling
# back to the pinned package.
find_newest() {
  newest_version="$PINNED_VERSION"
  newest_path="$PINNED_PACKAGE"
  local link
  for link in "$versions"/*; do
    [[ -x "$link/bin/claude-desktop" ]] || continue
    if version_gt "${link##*/}" "$newest_version"; then
      newest_version="${link##*/}"
      newest_path="$(readlink -f "$link")"
    fi
  done
}

say() {
  printf '%s %s\n' "$(date -Is)" "$*"
}

update() {
  local now valid_until packages_sha latest version filename sha256 link
  # Global, not local: the EXIT trap runs after this function returns.
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  export GNUPGHOME="$tmp"

  curl -fsS --proto '=https' --max-time 20 "$repo/dists/stable/InRelease" -o "$tmp/InRelease" ||
    { say "Could not fetch InRelease"; return 1; }
  if ! gpgv --keyring "$KEYRING" --output "$tmp/Release" "$tmp/InRelease" 2>"$tmp/gpgv.log"; then
    say "InRelease signature check FAILED; not updating"
    cat "$tmp/gpgv.log"
    return 1
  fi

  now="$(date +%s)"
  valid_until="$(awk -F': ' '$1 == "Valid-Until" { print $2 }' "$tmp/Release")"
  if [[ -z "$valid_until" ]] || (($(date -d "$valid_until" +%s) < now)); then
    say "InRelease is expired (Valid-Until: ${valid_until:-missing}); not updating"
    return 1
  fi

  packages_sha="$(awk -v file="main/binary-$DEB_ARCH/Packages" '
    /^[^ ]/ { in_sha256 = ($0 == "SHA256:") }
    in_sha256 && $3 == file { print $1 }
  ' "$tmp/Release")"
  if [[ ! "$packages_sha" =~ ^[0-9a-f]{64}$ ]]; then
    say "No Packages hash for $DEB_ARCH in InRelease; not updating"
    return 1
  fi
  curl -fsS --proto '=https' --max-time 30 \
    "$repo/dists/stable/main/binary-$DEB_ARCH/by-hash/SHA256/$packages_sha" -o "$tmp/Packages" ||
    { say "Could not fetch Packages"; return 1; }
  if ! printf '%s  %s\n' "$packages_sha" "$tmp/Packages" | sha256sum --check --status; then
    say "Packages does not match the signed hash; not updating"
    return 1
  fi

  latest="$(awk '
    BEGIN { RS = ""; FS = "\n" }
    {
      package = version = filename = sha256 = ""
      for (i = 1; i <= NF; i++) {
        if ($i == "Package: claude-desktop") package = 1
        else if ($i ~ /^Version: /) version = substr($i, 10)
        else if ($i ~ /^Filename: /) filename = substr($i, 11)
        else if ($i ~ /^SHA256: /) sha256 = substr($i, 9)
      }
      if (package) print version "\t" filename "\t" sha256
    }
  ' "$tmp/Packages" | sort -t "$(printf '\t')" -k1,1V | tail -n 1)"
  IFS=$'\t' read -r version filename sha256 <<<"$latest"

  if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+)*$ ]] ||
    [[ "$filename" != "pool/main/c/claude-desktop/claude-desktop_${version}_${DEB_ARCH}.deb" ]] ||
    [[ ! "$sha256" =~ ^[0-9a-f]{64}$ ]]; then
    say "Unexpected index entry: ${latest:-none}; not updating"
    return 1
  fi

  find_newest
  if ! version_gt "$version" "$newest_version"; then
    return 0
  fi
  if [[ -e "$state/failed-$version" ]]; then
    return 0
  fi

  say "Building Claude Desktop $version (have $newest_version)"
  if ! nix build --file "$UPDATE_EXPR" \
    --argstr version "$version" \
    --argstr sha256 "$sha256" \
    --out-link "$versions/$version"; then
    say "Build of $version failed; staying on $newest_version until the next release"
    touch "$state/failed-$version"
    notify-send --app-name=Claude --icon=claude-desktop \
      "Claude Desktop $version could not be built" "Still using $newest_version. Details: $log" || true
    return 1
  fi

  for link in "$versions"/*; do
    [[ "${link##*/}" == "$version" ]] || rm -f "$link"
  done
  rm -f "$state"/failed-*
  say "Claude Desktop $version is ready"
  notify-send --app-name=Claude --icon=claude-desktop \
    "Claude Desktop $version is ready" "Quit and reopen Claude to use it." || true
}

if [[ "${CLAUDE_DESKTOP_UPDATE_WORKER:-}" == 1 ]]; then
  exec 9>"$state/lock"
  flock --nonblock 9 || exit 0
  if [[ -e "$state/last-check" ]] &&
    (($(date +%s) - $(stat -c %Y "$state/last-check") < check_interval)); then
    exit 0
  fi
  touch "$state/last-check"
  if [[ -e "$log" ]]; then
    tail -n 500 "$log" >"$log.tmp" && mv "$log.tmp" "$log"
  fi
  update >>"$log" 2>&1 || exit 0
  exit 0
fi

if [[ "${CLAUDE_DESKTOP_AUTO_UPDATE:-1}" != 0 ]]; then
  CLAUDE_DESKTOP_UPDATE_WORKER=1 setsid --fork "$0" </dev/null >/dev/null 2>&1 || true
fi

find_newest
exec "$newest_path/bin/claude-desktop" "$@"
