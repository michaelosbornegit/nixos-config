# Explicit Vercel AI Gateway launchers for Claude Code and Codex.
#
# Plain `claude` / `codex` always use their normal providers. These commands
# route a single invocation through the Gateway instead; nothing is written to
# either agent's config, so there is no global state to toggle or clean up.
# Secrets stay in the macOS Keychain and are only read (never written) by the
# launchers themselves — writing happens only in vercel-gateway-key, below.
#
# macOS only: keys are read via /usr/bin/security (Keychain). On Linux a
# different secret backend (secret-tool, pass, or a file) would be needed.
#
# Usage: claude-vercel <claude args…>  (any shell — claude is a real binary)
#        codex-vercel <codex args…>    (interactive zsh only — codex is a zsh
#                                       function, see home-common.nix)
#
# claude-vercel without --model opens an fzf picker over the Gateway's live
# model list, showing each model's release date, context window and price. The
# last 8 picks come first, most recent first, marked "*"; everything else
# follows by release date, newest first (Enter alone therefore reuses the last
# pick). An unknown --model opens the picker pre-filtered rather than failing
# at the API, which is how an upstream rename gets fixed. Non-interactive runs
# (no TTY) reuse the last pick silently.
#
# Both launchers also accept --key <name> to use a *named* Gateway key instead
# of the single default one — see vercel-gateway-key below for creating and
# managing named keys. With no --key, every interactive run opens an fzf key
# picker first (same recency precedent as the model picker; Esc there cancels
# the whole run, same as an unpicked model). The picker always offers the
# original default Keychain entry ("(default)"), every registered named key,
# and a "+ create a new named key" entry that prompts for a name and creates
# one on the spot.
#
# State: $XDG_STATE_HOME/claude-vercel/recent-models-<account> (the pick list)
# and $XDG_CACHE_HOME/claude-vercel/models.v2.<account>.tsv (the model list,
# refetched every 6h) — namespaced per account because different Gateway keys
# can belong to different teams with different model allowlists (ZDR, BYOK).
# vercel-gateway-model keeps the same pair under vercel-gateway-model/ for the
# codex list. All of it is disposable — deleting it only loses the pick order.
#
# Model choice: pass --model / -m for a Gateway model on a given run, e.g.
#   claude-vercel --model zai/glm-5.3-fast[1m]   (claude-code/ prefix optional)
#   codex-vercel -m zai/glm-5.3-fast
# codex-vercel without -m opens the same style of fzf picker over the
# Gateway's codex model list (slug, display name, context window; that
# endpoint carries no pricing). An unknown -m opens it pre-filtered;
# non-interactive runs reuse the last pick silently. An explicit -m bypasses
# the picker.
# Avoid picking a Gateway-only model via the in-session /model command: both
# agents persist that to their shared config, and plain `claude` / `codex`
# would then fail against their normal providers on the next launch.
{
  lib,
  pkgs,
  ...
}: let
  keychainService = "Vercel AI Gateway";
  keychainAccount = "vercel-ai-gateway";

  # Team a freshly created named key lands in unless --scope overrides it.
  # This machine's ambient `vercel` CLI scope is a client team, but every
  # existing coding-agent key actually lives under blank-metal, so that — not
  # the CLI's ambient default — is what we default to here.
  defaultKeyTeam = "blank-metal";

  pickerLib = pkgs.writeText "vercel-ai-gateway-picker-lib.sh" (builtins.readFile ./vercel-ai-gateway/picker-lib.sh);

  # Formats the Gateway's model list into the picker's cache: one row per
  # model, "<id>\t<display>", newest release first. The id is repeated inside
  # the display text because fzf only searches the fields it displays.
  modelsToTsv = pkgs.writeText "claude-vercel-models.jq" ''
    def rpad($n): tostring | . + (($n - length) as $d | if $d > 0 then " " * $d else "" end);
    def permil: if . == null then "?" else (tonumber * 1e6 * 1000 | round / 1000 | tostring) end;
    .data
    | map(select(.type == "language"))
    | sort_by(-(.released // 0))
    | .[]
    | (.id | sub("^claude-code/"; "")) as $id
    | [ $id,
        ($id | rpad(42)) + " "
        + (if .released == null then "unknown" else (.released | todate | .[:10]) end | rpad(10)) + " "
        + (((.context_window // 0) / 1000 | floor | tostring) + "k" | rpad(7)) + " "
        + ("$" + (.pricing.input | permil) + "/$" + (.pricing.output | permil) + " per M")
      ] | @tsv
  '';

  # Named-key management: create (via the real `vercel ai-gateway api-keys
  # create` — never reimplemented), list with liveness checked against the
  # server, and pick — reusing picker-lib.sh, the same generic helpers the
  # model picker uses, per the precedent it was written to support.
  #
  # "Valid" only ever means: a secret this tool already has in Keychain, whose
  # server-side record isn't expired, leaked, or archived. `list`/`inspect`
  # never return a usable secret, so a key that lives on the server but was
  # never created through here can't enter the picker at all.
  vercelGatewayKey = pkgs.writeShellApplication {
    name = "vercel-gateway-key";
    runtimeInputs = [pkgs.coreutils pkgs.findutils pkgs.fzf pkgs.gawk pkgs.jq];
    text = ''
      # shellcheck source=/dev/null
      source ${pickerLib}

      keychain_service=${lib.escapeShellArg keychainService}
      keychain_account=${lib.escapeShellArg keychainAccount}
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/vercel-gateway-key"
      cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/vercel-gateway-key"
      index_file="$state_dir/keys.tsv"
      mkdir -p "$state_dir"

      usage() {
        echo "usage: vercel-gateway-key new <name> [--scope TEAM] [--budget N] [--expiration PERIOD] [--refresh-period PERIOD]" >&2
        echo "       vercel-gateway-key ls" >&2
        echo "       vercel-gateway-key pick" >&2
        echo "       vercel-gateway-key adopt-default <name> [team]" >&2
      }

      cmd_new() {
        local name="" team="${defaultKeyTeam}"
        local -a extra=()
        while (($#)); do
          case "$1" in
            --scope | --team)
              team="''${2:?$1 requires a value}"
              shift 2
              ;;
            --scope=*) team="''${1#--scope=}"; shift ;;
            --team=*) team="''${1#--team=}"; shift ;;
            --budget | --limit)
              extra+=(--limit "''${2:?$1 requires a value}")
              shift 2
              ;;
            --budget=*) extra+=(--limit "''${1#--budget=}"); shift ;;
            --limit=*) extra+=(--limit "''${1#--limit=}"); shift ;;
            --expiration)
              extra+=(--expiration "''${2:?--expiration requires a value}")
              shift 2
              ;;
            --expiration=*) extra+=(--expiration "''${1#--expiration=}"); shift ;;
            --refresh-period)
              extra+=(--refresh-period "''${2:?--refresh-period requires a value}")
              shift 2
              ;;
            --refresh-period=*) extra+=(--refresh-period "''${1#--refresh-period=}"); shift ;;
            -*)
              echo "vercel-gateway-key: unknown option $1" >&2
              exit 1
              ;;
            *)
              if [[ -z "$name" ]]; then
                name="$1"
              else
                echo "vercel-gateway-key: unexpected argument $1" >&2
                exit 1
              fi
              shift
              ;;
          esac
        done
        if [[ -z "$name" ]]; then
          usage
          exit 1
        fi
        if [[ "$name" == *$'\t'* || "$name" == *$'\n'* ]]; then
          echo "vercel-gateway-key: name cannot contain tabs or newlines" >&2
          exit 1
        fi

        local err_file
        err_file="$(mktemp)"
        local key=""
        # vercel's own confirmation (and the key id inside it) goes to
        # stderr; only the plaintext key itself is written to stdout. Capture
        # stderr to a file rather than a live tee: the spinner doesn't render
        # sensibly through a pipe anyway, and this avoids a process-
        # substitution race against reading the file back below.
        if ! key="$(vercel ai-gateway api-keys create --name "$name" --scope "$team" "''${extra[@]}" 2>"$err_file")"; then
          cat "$err_file" >&2
          rm -f "$err_file"
          exit 1
        fi
        cat "$err_file" >&2
        if [[ -z "$key" ]]; then
          rm -f "$err_file"
          echo "vercel-gateway-key: 'vercel ai-gateway api-keys create' printed no key; nothing stored." >&2
          exit 1
        fi
        local key_id=""
        key_id="$(grep -oE '\([A-Za-z0-9]+\) created' "$err_file" | head -n1 | sed -E 's/^\(([A-Za-z0-9]+)\).*/\1/' || true)"
        rm -f "$err_file"

        /usr/bin/security add-generic-password -s "$keychain_service" -a "$keychain_account-$name" -w "$key" -U >/dev/null
        key=""

        local tmp
        tmp="$(mktemp "$index_file.XXXXXX")"
        if [[ -s "$index_file" ]]; then
          awk -F'\t' -v n="$name" '$1 != n' "$index_file" >"$tmp"
        fi
        printf '%s\t%s\t%s\n' "$name" "$team" "$key_id" >>"$tmp"
        mv "$tmp" "$index_file"
        echo "vercel-gateway-key: stored '$name' (team $team) in Keychain as $keychain_account-$name." >&2
      }

      cmd_adopt_default() {
        local name="''${1:?usage: vercel-gateway-key adopt-default <name> [team]}"
        local team="''${2:-${defaultKeyTeam}}"
        local secret=""
        secret="$(/usr/bin/security find-generic-password -s "$keychain_service" -a "$keychain_account" -w 2>/dev/null || true)"
        if [[ -z "$secret" ]]; then
          echo "vercel-gateway-key: no existing default Keychain entry ($keychain_service / $keychain_account) to adopt." >&2
          exit 1
        fi
        /usr/bin/security add-generic-password -s "$keychain_service" -a "$keychain_account-$name" -w "$secret" -U >/dev/null
        secret=""
        local tmp
        tmp="$(mktemp "$index_file.XXXXXX")"
        if [[ -s "$index_file" ]]; then
          awk -F'\t' -v n="$name" '$1 != n' "$index_file" >"$tmp"
        fi
        printf '%s\t%s\t%s\n' "$name" "$team" "" >>"$tmp"
        mv "$tmp" "$index_file"
        echo "vercel-gateway-key: registered today's default key as '$name' (team $team)." >&2
      }

      # Refreshes (6h TTL, stale-on-failure) the cached live key list for one
      # team. Only ever used to tell whether a locally-stored key is still
      # valid — list/inspect never return anything usable as a secret.
      fetch_team_keys() {
        local team="$1"
        local cache="$cache_dir/apikeys.$team.json"
        mkdir -p "$cache_dir"
        if [[ ! -s "$cache" || -n "$(find "$cache" -mmin +360 2>/dev/null)" ]]; then
          local tmp
          tmp="$(mktemp "$cache.XXXXXX")"
          if vercel ai-gateway api-keys list --format json --scope "$team" --limit 100 >"$tmp" 2>/dev/null && [[ -s "$tmp" ]]; then
            mv "$tmp" "$cache"
          else
            rm -f "$tmp"
          fi
        fi
      }

      # Emits name\tteam\tstatus for every registered row. status is one of
      # ok|expired|leaked|archived|missing|unknown (unknown = couldn't check,
      # e.g. offline — treated as usable rather than hidden).
      rows_with_status() {
        if [[ ! -s "$index_file" ]]; then
          return 0
        fi
        local teams team
        teams="$(cut -f2 "$index_file" | sort -u)"
        while read -r team; do
          if [[ -n "$team" ]]; then
            fetch_team_keys "$team"
          fi
        done <<<"$teams"

        local name key_id cache status
        while IFS=$'\t' read -r name team key_id; do
          if [[ -z "$name" ]]; then
            continue
          fi
          cache="$cache_dir/apikeys.$team.json"
          status="unknown"
          # Only a key created through `new` (which passed --name to the
          # server itself) has an id to check by. An adopted key's local
          # name was never sent to the server, so there's nothing reliable
          # to match it against — leave it "unknown" rather than guessing by
          # name, which could match an unrelated same-named key or report a
          # false "missing" and silently drop it from the picker.
          if [[ -n "$key_id" && -s "$cache" ]]; then
            status="$(jq -r --arg id "$key_id" '
                (.apiKeys // []) as $keys
                | ([$keys[] | select(.id == $id)]) as $m
                | if ($m | length) == 0 then "missing"
                  elif ($m[0].leakedAt // null) != null then "leaked"
                  elif (($m[0].quota // {}).archived // false) then "archived"
                  elif ($m[0].expiresAt // null) != null and ($m[0].expiresAt < (now * 1000)) then "expired"
                  else "ok" end
              ' "$cache" 2>/dev/null || echo unknown)"
          fi
          printf '%s\t%s\t%s\n' "$name" "$team" "$status"
        done <"$index_file"
      }

      cmd_ls() {
        if [[ ! -s "$index_file" ]]; then
          echo "vercel-gateway-key: no named keys registered yet. Run 'vercel-gateway-key new <name>'." >&2
          return 0
        fi
        printf '%-24s %-20s %s\n' "NAME" "TEAM" "STATUS"
        rows_with_status | while IFS=$'\t' read -r name team status; do
          printf '%-24s %-20s %s\n' "$name" "$team" "$status"
        done
      }

      # name\tdisplay for the picker's cache: always a sentinel to create a
      # new key, the original default account if it exists, and every
      # registered named key the server still reports as live (or that we
      # couldn't check). __new__ and __default__ are reserved ids a caller of
      # `pick` must handle specially; no real key is ever named that, since
      # cmd_new rejects names containing tabs/newlines but these are plain
      # words — collision is already vanishingly unlikely, and even a literal
      # same-named key would just be shadowed by the sentinel, never mixed up
      # with a Keychain account (there is no "vercel-ai-gateway-__new__").
      cache_tsv() {
        printf '__new__\t+ create a new named key\n'
        if /usr/bin/security find-generic-password -s "$keychain_service" -a "$keychain_account" >/dev/null 2>&1; then
          printf '__default__\t(default)\n'
        fi
        rows_with_status | awk -F'\t' '$3 == "ok" || $3 == "unknown" { print $1 "\t" $1 "  (" $2 ")" }'
      }

      # Prints the chosen key name on stdout: a registered name, or the
      # literal "__default__" meaning the original default account (the
      # caller — claude-vercel/codex-vercel — interprets that). Choosing
      # "+ create a new named key" prompts for a name on /dev/tty, creates it
      # via cmd_new, and returns that name instead.
      cmd_pick() {
        local cache
        cache="$(mktemp)"
        cache_tsv >"$cache"
        local mru_file="$state_dir/recent"
        local chosen status
        if chosen="$(mru_pick "$mru_file" "$cache" "" "key> " "* = recent · then alphabetical · Esc cancels")"; then
          status=0
        else
          status=$?
        fi
        rm -f "$cache"
        if ((status != 0)); then
          exit "$status"
        fi
        if [[ -z "$chosen" ]]; then
          exit 130
        fi

        if [[ "$chosen" == "__new__" ]]; then
          local new_name=""
          read -r -p "New key name: " new_name </dev/tty || true
          if [[ -z "$new_name" ]]; then
            exit 130
          fi
          cmd_new "$new_name"
          chosen="$new_name"
        fi

        mru_record "$mru_file" "$chosen"
        printf '%s\n' "$chosen"
      }

      case "''${1-}" in
        new)
          shift
          cmd_new "$@"
          ;;
        ls)
          shift
          cmd_ls "$@"
          ;;
        pick)
          shift
          cmd_pick "$@"
          ;;
        adopt-default)
          shift
          cmd_adopt_default "$@"
          ;;
        *)
          usage
          exit 1
          ;;
      esac
    '';
  };

  # Formats the Gateway's *codex* model list into the picker's cache. That
  # endpoint has a different shape from the claude-code one: {"models": […]}
  # keyed by "slug", with display_name and context_window but no pricing or
  # release date, ordered by the server's own priority (newest first, roughly).
  # Keep the server order — there's no release-date field to sort by.
  codexModelsToTsv = pkgs.writeText "vercel-gateway-model-codex.jq" ''
    def rpad($n): tostring | . + (($n - length) as $d | if $d > 0 then " " * $d else "" end);
    .models
    | map(select(.visibility == "list"))
    | .[]
    | [ .slug,
        (.slug | rpad(40)) + " "
        + ((.display_name // .slug) | rpad(26)) + " "
        + ((((.context_window // 0) / 1000) | floor | tostring) + "k")
      ] | @tsv
  '';

  # codex-vercel's half of the model picker. claude-vercel keeps its copy
  # inline because its flow is interwoven with --model arg handling; this tool
  # exists because codex-vercel is a zsh function and shells out instead. The
  # pick/last/check contract mirrors what claude-vercel does inline:
  #   pick  — fzf picker over the cached list; prints the chosen slug,
  #           exit 130 on Esc/cancel, exit 1 if there's no list to pick from.
  #   last  — the newest still-valid previous pick; prints nothing if none.
  #   check — exit 0 if the slug is in the cache, 1 otherwise (no cache = 1).
  # State is namespaced per keychain account, same reasoning as claude-vercel.
  vercelGatewayModel = pkgs.writeShellApplication {
    name = "vercel-gateway-model";
    runtimeInputs = [pkgs.coreutils pkgs.curl pkgs.findutils pkgs.fzf pkgs.gawk pkgs.jq];
    text = ''
      # shellcheck source=/dev/null
      source ${pickerLib}

      keychain_service=${lib.escapeShellArg keychainService}
      keychain_account=${lib.escapeShellArg keychainAccount}

      usage() {
        echo "usage: vercel-gateway-model pick [--account ACCOUNT] [--query QUERY]" >&2
        echo "       vercel-gateway-model last [--account ACCOUNT]" >&2
        echo "       vercel-gateway-model check <model> [--account ACCOUNT]" >&2
      }

      cmd=""
      account="$keychain_account"
      query=""
      check_id=""
      while (($#)); do
        case "$1" in
          pick | last | check)
            cmd="$1"
            shift
            ;;
          --account | -a)
            account="''${2:?$1 requires a value}"
            shift 2
            ;;
          --account=*)
            account="''${1#--account=}"
            shift
            ;;
          --query | -q)
            query="''${2:?$1 requires a value}"
            shift 2
            ;;
          --query=*)
            query="''${1#--query=}"
            shift
            ;;
          -h | --help)
            usage
            exit 0
            ;;
          *)
            if [[ "$cmd" == "check" && -z "$check_id" ]]; then
              check_id="$1"
            else
              usage
              exit 1
            fi
            shift
            ;;
        esac
      done
      if [[ -z "$cmd" || ("$cmd" == "check" && -z "$check_id") ]]; then
        usage
        exit 1
      fi

      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/vercel-gateway-model"
      cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/vercel-gateway-model"
      mru_file="$state_dir/recent-models-$account"
      cache_file="$cache_dir/models.codex.$account.tsv"
      mkdir -p "$state_dir" "$cache_dir"

      gateway_key="$(/usr/bin/security find-generic-password -s "$keychain_service" -a "$account" -w 2>/dev/null || true)"

      # Refreshed every 6h; a failed fetch keeps the stale copy.
      refresh_models() {
        local tmp
        tmp="$(mktemp "$cache_file.XXXXXX")"
        if [[ -n "$gateway_key" ]] &&
          curl -fsS --max-time 5 -H "Authorization: Bearer $gateway_key" \
            https://ai-gateway.vercel.sh/codex/v1/models |
          jq -r -f ${codexModelsToTsv} >"$tmp" && [[ -s "$tmp" ]]; then
          mv "$tmp" "$cache_file"
        else
          rm -f "$tmp"
          return 1
        fi
      }
      if [[ ! -s "$cache_file" || -n "$(find "$cache_file" -mmin +360 2>/dev/null)" ]]; then
        refresh_models || echo "vercel-gateway-model: couldn't fetch the Gateway model list; using cache." >&2
      fi
      have_cache() { [[ -s "$cache_file" ]]; }
      known_model() {
        have_cache || return 1
        awk -F'\t' -v id="$1" '$1 == id { found = 1; exit } END { exit !found }' "$cache_file"
      }
      # The newest pick that still exists upstream: a model renamed since it
      # was last used must not silently come back as the default.
      last_model() {
        local id
        have_cache || { head -n1 "$mru_file" 2>/dev/null || true; return 0; }
        [[ -s "$mru_file" ]] || return 0
        while read -r id; do
          if [[ -n "$id" ]] && known_model "$id"; then
            printf '%s\n' "$id"
            return 0
          fi
        done <"$mru_file"
      }

      case "$cmd" in
        pick)
          # No tty gate here: callers invoke this under command substitution
          # (stdout is a pipe), and fzf renders on /dev/tty by itself — that's
          # how vercel-gateway-key pick works under the same pattern. With no
          # controlling terminal at all, fzf exits 2 and the caller falls back.
          have_cache || { echo "vercel-gateway-model: no model list available yet." >&2; exit 1; }
          last=""
          [[ -s "$mru_file" ]] && last="$(last_model)"
          header="* = recent · then list order · Esc cancels"
          if [[ -n "$last" ]]; then header="Enter = $last · $header"; fi
          model=""
          status=0
          model="$(mru_pick "$mru_file" "$cache_file" "$query" "model> " "$header")" || status=$?
          if ((status != 0)); then
            exit "$status"
          fi
          [[ -n "$model" ]] || exit 130
          mru_record "$mru_file" "$model"
          printf '%s\n' "$model"
          ;;
        last)
          last_model
          ;;
        check)
          known_model "$check_id"
          ;;
      esac
    '';
  };

  claudeVercel = pkgs.writeShellApplication {
    name = "claude-vercel";
    runtimeInputs = [pkgs.coreutils pkgs.curl pkgs.findutils pkgs.fzf pkgs.gawk pkgs.jq];
    text = ''
      # shellcheck source=/dev/null
      source ${pickerLib}

      keychain_service=${lib.escapeShellArg keychainService}
      keychain_account=${lib.escapeShellArg keychainAccount}

      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/claude-vercel"
      cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/claude-vercel"
      mkdir -p "$state_dir" "$cache_dir"

      # --- split our --model/--key out of args before anything else: which
      # --- Keychain account to read depends on --key, and the subcommand
      # --- passthrough below must see the remaining positional args.
      model=""
      key_name=""
      interactive=1
      args=()
      while (($#)); do
        case "$1" in
          --model)
            model="''${2-}"
            shift
            (($#)) && shift
            ;;
          --model=*)
            model="''${1#--model=}"
            shift
            ;;
          --key)
            key_name="''${2-}"
            shift
            (($#)) && shift
            ;;
          --key=*)
            key_name="''${1#--key=}"
            shift
            ;;
          -h | --help | -v | --version)
            interactive=0
            args+=("$1")
            shift
            ;;
          --)
            args+=("$@")
            break
            ;;
          *)
            args+=("$1")
            shift
            ;;
        esac
      done
      [[ -t 0 && -t 1 ]] || interactive=0
      # Ids are stored and shown without the Gateway's claude-code/ prefix.
      model="''${model#claude-code/}"

      # --- resolve which Keychain account to read. --key names one; with
      # --- none given, every interactive run opens the key picker (same
      # --- recency precedent as the model picker — Esc there cancels the
      # --- whole run, same as an unpicked model). The picker always offers
      # --- the default account, every named key, and a "create new" entry.
      account="$keychain_account"
      if [[ -n "$key_name" ]]; then
        account="$keychain_account-$key_name"
      elif ((interactive)); then
        chosen="$(vercel-gateway-key pick)" || exit 130
        [[ -n "$chosen" ]] || exit 130
        if [[ "$chosen" != "__default__" ]]; then
          account="$keychain_account-$chosen"
        fi
      fi

      gateway_key="$(/usr/bin/security find-generic-password -s "$keychain_service" -a "$account" -w 2>/dev/null || true)"
      if [[ -z "$gateway_key" ]]; then
        echo "claude-vercel: macOS Keychain entry $keychain_service / $account not found." >&2
        if [[ "$account" == "$keychain_account" ]]; then
          echo "claude-vercel: run 'vercel ai-gateway setup' once to create it, or 'vercel-gateway-key new <name>' for a named key." >&2
        else
          key_display_name="''${account#"$keychain_account"-}"
          echo "claude-vercel: run 'vercel-gateway-key new $key_display_name' to create it." >&2
        fi
        exit 1
      fi
      export ANTHROPIC_BASE_URL="https://ai-gateway.vercel.sh/claude-code"
      export ANTHROPIC_AUTH_TOKEN="$gateway_key"
      # Empty string is treated as unset; without this a shell-inherited API
      # key would conflict with AUTH_TOKEN.
      export ANTHROPIC_API_KEY=""
      export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY="1"

      # Subcommands (mcp, doctor, …) take no model or key; pass straight through.
      case "''${args[0]-}" in
        mcp | config | doctor | update | upgrade | install | plugin | setup-token | migrate-installer)
          exec claude "''${args[@]}"
          ;;
      esac

      mru_file="$state_dir/recent-models-$account"
      cache_file="$cache_dir/models.v2.$account.tsv"

      # Migration from the single-slot/5-column layout. Only applies to the
      # default account — named accounts never had the old-format state.
      if [[ "$account" == "$keychain_account" && -s "$state_dir/last-model" ]]; then
        mru_record "$mru_file" "$(head -n1 "$state_dir/last-model")"
      fi
      rm -f "$state_dir/last-model" "$cache_dir/models.tsv"

      # --- model list: refreshed every 6h; a failed fetch keeps the stale copy.
      refresh_models() {
        local tmp
        tmp="$(mktemp "$cache_file.XXXXXX")"
        if curl -fsS --max-time 5 -H "Authorization: Bearer $gateway_key" \
          https://ai-gateway.vercel.sh/claude-code/v1/models |
          jq -r -f ${modelsToTsv} >"$tmp" && [[ -s "$tmp" ]]; then
          mv "$tmp" "$cache_file"
        else
          rm -f "$tmp"
          return 1
        fi
      }
      if [[ ! -s "$cache_file" || -n "$(find "$cache_file" -mmin +360 2>/dev/null)" ]]; then
        refresh_models || echo "claude-vercel: couldn't fetch the Gateway model list; using cache." >&2
      fi
      have_cache() { [[ -s "$cache_file" ]]; }
      known_model() {
        have_cache || return 1
        awk -F'\t' -v id="$1" '$1 == id { found = 1; exit } END { exit !found }' "$cache_file"
      }
      # The newest pick that still exists upstream: a model renamed since it was
      # last used must not silently come back as the default.
      last_model() {
        local id
        have_cache || { head -n1 "$mru_file" 2>/dev/null || true; return 0; }
        while read -r id; do
          if [[ -n "$id" ]] && known_model "$id"; then
            printf '%s\n' "$id"
            return 0
          fi
        done <"$mru_file"
      }

      picker_header() {
        local hint="* = recent · then newest release first · Esc cancels"
        if [[ -n "$last" ]]; then echo "Enter = $last · $hint"; else echo "$hint"; fi
      }

      last=""
      [[ -s "$mru_file" ]] && last="$(last_model)"

      if [[ -n "$model" ]] && ! known_model "$model"; then
        # Wrong or renamed id: offer the picker rather than failing at the API.
        if ((interactive)) && have_cache; then
          echo "claude-vercel: '$model' isn't a Gateway model; pick one:" >&2
          model="$(mru_pick "$mru_file" "$cache_file" "$model" "model> " "$(picker_header)")" || true
          [[ -n "$model" ]] || exit 130
        elif have_cache; then
          echo "claude-vercel: warning: '$model' isn't in the Gateway model list." >&2
        fi
      elif [[ -z "$model" ]]; then
        if ((interactive)) && have_cache; then
          model="$(mru_pick "$mru_file" "$cache_file" "" "model> " "$(picker_header)")" || true
          [[ -n "$model" ]] || exit 130
        else
          model="$last"
        fi
      fi

      model_args=()
      if [[ -n "$model" ]]; then
        if ! have_cache || known_model "$model"; then mru_record "$mru_file" "$model"; fi
        model_args=(--model "claude-code/$model")
      fi

      # The Gateway cannot serve WebSearch (a first-party server-side tool).
      # Variadic flag — keep it after the args so a positional prompt is not
      # swallowed into the tool list.
      exec claude "''${model_args[@]}" "''${args[@]}" --disallowedTools WebSearch
    '';
  };
in {
  # Fail the build loudly if this ever gets imported on a non-darwin host.
  assertions = [
    {
      assertion = pkgs.stdenv.hostPlatform.isDarwin;
      message = "vercel-ai-gateway.nix requires macOS: it reads the API key from the Keychain via /usr/bin/security.";
    }
  ];

  home.packages = [claudeVercel vercelGatewayKey vercelGatewayModel];

  programs.zsh.initContent = lib.mkAfter ''
    # >>> vercel ai-gateway (nix-managed) >>>
    # A zsh function (not a package) because codex itself is a zsh function.
    # The -c flags layer on top of config.toml for this run only; forced flags
    # come first so a user's own later -c overrides win.
    #
    # --key <name> picks a named Gateway key the same way claude-vercel does
    # (see vercel-ai-gateway.nix and vercel-gateway-key); with none given,
    # every interactive run opens the same fzf key picker first.
    #
    # Models mirror claude-vercel via vercel-gateway-model: with no -m, every
    # interactive run opens an fzf picker over the Gateway's codex model list
    # (Esc cancels the run); a -m naming an unknown model opens the picker
    # pre-filtered; non-interactive runs silently reuse the last pick.
    codex-vercel() {
      local keychain_service=${lib.escapeShellArg keychainService}
      local keychain_account=${lib.escapeShellArg keychainAccount}
      local key_name="" account chosen="" gateway_key key_display_name
      local model_given=0 model_value="" model="" picked=""
      local -a args=()
      local -a model_args=()
      while (($#)); do
        case "$1" in
          --key)
            key_name="''${2-}"
            shift
            (($#)) && shift
            ;;
          --key=*)
            key_name="''${1#--key=}"
            shift
            ;;
          -m | --model)
            model_given=1
            model_value="''${2-}"
            shift
            (($#)) && shift
            ;;
          --model=*)
            model_given=1
            model_value="''${1#--model=}"
            shift
            ;;
          --)
            args+=("$@")
            break
            ;;
          *)
            args+=("$1")
            shift
            ;;
        esac
      done
      # A bare -m with no value is treated as "no model given", so the picker
      # opens instead of codex failing on an empty -m.
      if ((model_given)) && [[ -z "$model_value" ]]; then
        model_given=0
      fi

      account="$keychain_account"
      if [[ -n "$key_name" ]]; then
        account="$keychain_account-$key_name"
      elif [[ -t 0 && -t 1 ]]; then
        chosen="$(vercel-gateway-key pick)" || return 130
        [[ -n "$chosen" ]] || return 130
        if [[ "$chosen" != "__default__" ]]; then
          account="$keychain_account-$chosen"
        fi
      fi

      if ! gateway_key="$(/usr/bin/security find-generic-password -s "$keychain_service" -a "$account" -w 2>/dev/null)" || [[ -z "$gateway_key" ]]; then
        echo "codex-vercel: macOS Keychain entry $keychain_service / $account not found." >&2
        if [[ "$account" == "$keychain_account" ]]; then
          echo "codex-vercel: run 'vercel ai-gateway setup' once to create it, or 'vercel-gateway-key new <name>' for a named key." >&2
        else
          key_display_name="''${account#"$keychain_account"-}"
          echo "codex-vercel: run 'vercel-gateway-key new $key_display_name' to create it." >&2
        fi
        return 1
      fi
      # local -x exports only within this function's scope; the key never
      # lands in the interactive shell's environment.
      local -x AI_GATEWAY_API_KEY="$gateway_key"

      local interactive=0
      [[ -t 0 && -t 1 ]] && interactive=1

      # Model resolution, mirroring claude-vercel: explicit -m wins (validated
      # against the Gateway list, picker on unknown), otherwise pick
      # interactively or reuse the last pick silently.
      if ((model_given)); then
        if ! vercel-gateway-model check "$model_value" --account "$account"; then
          if ((interactive)); then
            echo "codex-vercel: '$model_value' isn't a Gateway model; pick one:" >&2
            if picked="$(vercel-gateway-model pick --account "$account" --query "$model_value")"; then
              model_value="$picked"
            elif [[ $? == 130 ]]; then
              return 130
            fi
          else
            echo "codex-vercel: warning: '$model_value' isn't in the Gateway model list." >&2
          fi
        fi
        model_args=(-m "$model_value")
      elif ((interactive)); then
        if model="$(vercel-gateway-model pick --account "$account")"; then
          model_args=(-m "$model")
        elif [[ $? == 130 ]]; then
          return 130
        else
          # No list to pick from (offline, first run): fall back like
          # claude-vercel does, to the last pick.
          model="$(vercel-gateway-model last --account "$account" 2>/dev/null || true)"
          [[ -n "$model" ]] && model_args=(-m "$model")
        fi
      else
        model="$(vercel-gateway-model last --account "$account" 2>/dev/null || true)"
        [[ -n "$model" ]] && model_args=(-m "$model")
      fi

      codex \
        -c model_provider=vercel \
        -c 'model_providers.vercel.name="Vercel AI Gateway"' \
        -c model_providers.vercel.base_url=https://ai-gateway.vercel.sh/codex/v1 \
        -c model_providers.vercel.env_key=AI_GATEWAY_API_KEY \
        -c model_providers.vercel.wire_api=responses \
        "''${model_args[@]}" \
        "''${args[@]}"
    }
    # <<< vercel ai-gateway (nix-managed) <<<
  '';
}
