# Toggle the Vercel AI Gateway for Codex and Claude Code.
#
# Runtime state lives in $HOME/.local/state/ai-gateway/enabled so toggling
# never needs a rebuild. The API key itself stays in the macOS Keychain and is
# only read (never written) by these commands.
#
# Usage: vercel-ai-gateway-on | vercel-ai-gateway-off
# Test overrides (not for interactive use):
#   VERCEL_AI_GATEWAY_STATE, VERCEL_AI_GATEWAY_CODEX_CONFIG,
#   VERCEL_AI_GATEWAY_CLAUDE_SETTINGS
{
  lib,
  pkgs,
  ...
}: let
  keychainService = "Vercel AI Gateway";
  keychainAccount = "vercel-ai-gateway";

  # Idempotent Codex (TOML) + Claude Code (settings.json) patcher. Reads and
  # writes agent config files in place; called with --enable or --disable plus
  # the two file paths. python3 is in the wrappers' runtimeInputs below.
  patchHelper = pkgs.writeText "vercel-ai-gateway-patch.py" (builtins.readFile ./vercel-ai-gateway/patch.py);

  gatewayOn = pkgs.writeShellApplication {
    name = "vercel-ai-gateway-on";
    runtimeInputs = with pkgs; [coreutils python3];
    text = ''
      state_file="''${VERCEL_AI_GATEWAY_STATE:-$HOME/.local/state/ai-gateway/enabled}"
      codex_config="''${VERCEL_AI_GATEWAY_CODEX_CONFIG:-$HOME/.codex/config.toml}"
      claude_settings="''${VERCEL_AI_GATEWAY_CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"

      if ! gateway_key="$(/usr/bin/security find-generic-password -s ${lib.escapeShellArg keychainService} -a ${lib.escapeShellArg keychainAccount} -w 2>/dev/null)"; then
        echo 'vercel-ai-gateway-on: macOS Keychain entry ${keychainService} / ${keychainAccount} not found.' >&2
        echo "vercel-ai-gateway-on: run 'vercel ai-gateway setup' once to create it." >&2
        exit 1
      fi
      if [[ -z "$gateway_key" ]]; then
        echo 'vercel-ai-gateway-on: Keychain returned an empty key.' >&2
        exit 1
      fi

      mkdir -p "$(dirname "$state_file")"
      for config_file in "$codex_config" "$claude_settings"; do
        if [[ -e "$config_file" && ! -e "$config_file.nix-gateway.bak" ]]; then
          cp -p "$config_file" "$config_file.nix-gateway.bak"
          echo "vercel-ai-gateway-on: backed up $config_file" >&2
        fi
      done

      if ! python3 ${patchHelper} --enable "$codex_config" "$claude_settings"; then
        echo 'vercel-ai-gateway-on: config patch failed; state file left untouched.' >&2
        exit 1
      fi

      touch "$state_file"
      echo 'vercel-ai-gateway-on: AI Gateway enabled for Codex and Claude Code.' >&2
      printf 'export AI_GATEWAY_API_KEY=%q\n' "$gateway_key"
      printf 'export ANTHROPIC_AUTH_TOKEN=%q\n' "$gateway_key"
    '';
  };

  gatewayOff = pkgs.writeShellApplication {
    name = "vercel-ai-gateway-off";
    runtimeInputs = with pkgs; [coreutils python3];
    text = ''
      state_file="''${VERCEL_AI_GATEWAY_STATE:-$HOME/.local/state/ai-gateway/enabled}"
      codex_config="''${VERCEL_AI_GATEWAY_CODEX_CONFIG:-$HOME/.codex/config.toml}"
      claude_settings="''${VERCEL_AI_GATEWAY_CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"

      if ! python3 ${patchHelper} --disable "$codex_config" "$claude_settings"; then
        echo 'vercel-ai-gateway-off: config patch failed.' >&2
        exit 1
      fi

      rm -f "$state_file"
      echo 'vercel-ai-gateway-off: AI Gateway disabled for Codex and Claude Code.' >&2
      printf 'unset AI_GATEWAY_API_KEY ANTHROPIC_AUTH_TOKEN\n'
    '';
  };
in {
  home.packages = [gatewayOn gatewayOff];

  programs.zsh.initContent = lib.mkAfter ''
    # >>> vercel ai-gateway (nix-managed) >>>
    # Runtime toggle for `vercel-ai-gateway-on` / `vercel-ai-gateway-off`.
    # Reads the key from the macOS Keychain on each new shell; nothing secret
    # is stored in the Nix store.
    if [[ -f "$HOME/.local/state/ai-gateway/enabled" ]]; then
      gateway_key="$(/usr/bin/security find-generic-password -s ${lib.escapeShellArg keychainService} -a ${lib.escapeShellArg keychainAccount} -w 2>/dev/null)"
      if [[ -n "$gateway_key" ]]; then
        export AI_GATEWAY_API_KEY="$gateway_key"
        export ANTHROPIC_AUTH_TOKEN="$gateway_key"
      fi
      unset gateway_key
    fi
    vercel-ai-gateway-on() { eval "$(command vercel-ai-gateway-on "$@")"; }
    vercel-ai-gateway-off() { eval "$(command vercel-ai-gateway-off "$@")"; }
    # <<< vercel ai-gateway (nix-managed) <<<
  '';
}
