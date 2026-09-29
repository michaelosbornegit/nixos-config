# Explicit Vercel AI Gateway launchers for Claude Code and Codex.
#
# Plain `claude` / `codex` always use their normal providers. These commands
# route a single invocation through the Gateway instead; nothing is written to
# either agent's config, so there is no global state to toggle or clean up.
# The API key stays in the macOS Keychain and is only read (never written).
#
# macOS only: the key is read via /usr/bin/security (Keychain). On Linux a
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
# State: $XDG_STATE_HOME/claude-vercel/recent-models (the pick list) and
# $XDG_CACHE_HOME/claude-vercel/models.v2.tsv (the model list, refetched every
# 6h). Both are disposable — deleting them only loses the pick order.
#
# Model choice: pass --model / -m for a Gateway model on a given run, e.g.
#   claude-vercel --model zai/glm-5.3-fast[1m]   (claude-code/ prefix optional)
#   codex-vercel -m zai/glm-5.3-fast
# Avoid picking a Gateway-only model via the in-session /model command: both
# agents persist that to their shared config, and plain `claude` / `codex`
# would then fail against their normal providers on the next launch.
#
# Future seam: --project <name> will swap keychainAccount for a per-project
# entry (same service, account vercel-ai-gateway-<name>).
{
  lib,
  pkgs,
  ...
}: let
  keychainService = "Vercel AI Gateway";
  keychainAccount = "vercel-ai-gateway";

  readKey = ''/usr/bin/security find-generic-password -s ${lib.escapeShellArg keychainService} -a ${lib.escapeShellArg keychainAccount} -w 2>/dev/null'';

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

  claudeVercel = pkgs.writeShellApplication {
    name = "claude-vercel";
    runtimeInputs = [pkgs.coreutils pkgs.curl pkgs.findutils pkgs.fzf pkgs.gawk pkgs.jq];
    text = ''
      gateway_key="$(${readKey})"
      if [[ -z "$gateway_key" ]]; then
        echo "claude-vercel: macOS Keychain entry ${keychainService} / ${keychainAccount} not found." >&2
        echo "claude-vercel: run 'vercel ai-gateway setup' once to create it." >&2
        exit 1
      fi
      export ANTHROPIC_BASE_URL="https://ai-gateway.vercel.sh/claude-code"
      export ANTHROPIC_AUTH_TOKEN="$gateway_key"
      # Empty string is treated as unset; without this a shell-inherited API
      # key would conflict with AUTH_TOKEN.
      export ANTHROPIC_API_KEY=""
      export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY="1"

      # Subcommands (mcp, doctor, …) take no model; pass straight through.
      case "''${1-}" in
        mcp | config | doctor | update | upgrade | install | plugin | setup-token | migrate-installer)
          exec claude "$@"
          ;;
      esac

      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/claude-vercel"
      cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/claude-vercel"
      mru_file="$state_dir/recent-models"
      cache_file="$cache_dir/models.v2.tsv"
      mkdir -p "$state_dir" "$cache_dir"

      # --- generic picker helpers. Kept free of model specifics so the planned
      # --- key picker can reuse them with a different cache producer.

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
      # cache order — i.e. recent picks, then newest release first — and prints
      # the chosen id. Ids missing from the cache (renamed upstream) drop out.
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

      # Migration from the single-slot/5-column layout. Folded in rather than
      # copied, so a pick made by an older build still installed on the machine
      # lands at the top of the list instead of being dropped.
      if [[ -s "$state_dir/last-model" ]]; then
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

      # --- split our --model out of the args; everything else passes through.
      model=""
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

  home.packages = [claudeVercel];

  programs.zsh.initContent = lib.mkAfter ''
    # >>> vercel ai-gateway (nix-managed) >>>
    # A zsh function (not a package) because codex itself is a zsh function.
    # The -c flags layer on top of config.toml for this run only; forced flags
    # come first so a user's own later -c overrides win.
    codex-vercel() {
      local gateway_key
      if ! gateway_key="$(${readKey})" || [[ -z "$gateway_key" ]]; then
        echo "codex-vercel: macOS Keychain entry ${keychainService} / ${keychainAccount} not found." >&2
        echo "codex-vercel: run 'vercel ai-gateway setup' once to create it." >&2
        return 1
      fi
      # local -x exports only within this function's scope; the key never
      # lands in the interactive shell's environment.
      local -x AI_GATEWAY_API_KEY="$gateway_key"
      codex \
        -c model_provider=vercel \
        -c 'model_providers.vercel.name="Vercel AI Gateway"' \
        -c model_providers.vercel.base_url=https://ai-gateway.vercel.sh/codex/v1 \
        -c model_providers.vercel.env_key=AI_GATEWAY_API_KEY \
        -c model_providers.vercel.wire_api=responses \
        "$@"
    }
    # <<< vercel ai-gateway (nix-managed) <<<
  '';
}
