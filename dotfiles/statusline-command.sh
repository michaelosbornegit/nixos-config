#!/usr/bin/env bash
# Claude Code status line — mirrors Powerlevel10k prompt style

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
session_name=$(echo "$input" | jq -r '.session_name // empty')
model=$(echo "$input" | jq -r '.model.display_name // .model.id // empty')

# Shorten path: replace $HOME with ~
short_cwd="${cwd/#$HOME/\~}"

# Git branch and status (skip optional locks)
git_branch=""
git_status=""
if [ -n "$cwd" ] && git -C "$cwd" -c core.fsmonitor=false rev-parse --git-dir >/dev/null 2>&1; then
  git_branch=$(git -C "$cwd" -c core.fsmonitor=false symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" -c core.fsmonitor=false rev-parse --short HEAD 2>/dev/null)

  if [ -n "$git_branch" ]; then
    # Collect status indicators
    status_flags=""
    porcelain=$(git -C "$cwd" -c core.fsmonitor=false status --porcelain 2>/dev/null)

    staged=$(echo "$porcelain" | grep -c '^[MADRC]' 2>/dev/null || echo 0)
    unstaged=$(echo "$porcelain" | grep -c '^.[MD]' 2>/dev/null || echo 0)
    untracked=$(echo "$porcelain" | grep -c '^??' 2>/dev/null || echo 0)

    [ "$staged" -gt 0 ] 2>/dev/null    && status_flags="${status_flags}+${staged}"
    [ "$unstaged" -gt 0 ] 2>/dev/null  && status_flags="${status_flags} !${unstaged}"
    [ "$untracked" -gt 0 ] 2>/dev/null && status_flags="${status_flags} ?${untracked}"
    status_flags="${status_flags# }"  # trim leading space

    # Ahead/behind tracking
    upstream=$(git -C "$cwd" -c core.fsmonitor=false rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
    if [ -n "$upstream" ]; then
      ahead=$(git -C "$cwd" -c core.fsmonitor=false rev-list --count "@{upstream}..HEAD" 2>/dev/null || echo 0)
      behind=$(git -C "$cwd" -c core.fsmonitor=false rev-list --count "HEAD..@{upstream}" 2>/dev/null || echo 0)
      [ "$ahead" -gt 0 ] 2>/dev/null  && status_flags="${status_flags:+${status_flags} }↑${ahead}"
      [ "$behind" -gt 0 ] 2>/dev/null && status_flags="${status_flags:+${status_flags} }↓${behind}"
    fi

    git_status="$status_flags"
  fi
fi

# Build status parts
parts=()

# Directory segment (cyan)
[ -n "$short_cwd" ] && parts+=("$(printf '\033[36m%s\033[0m' "$short_cwd")")

# Git branch + status segment (branch in magenta, status indicators in yellow)
if [ -n "$git_branch" ]; then
  if [ -n "$git_status" ]; then
    parts+=("$(printf '\033[33m%s\033[0m \033[35m \033[0m%s' "$git_status" "$git_branch")")
  else
    parts+=("$(printf '\033[35m \033[0m%s' "$git_branch")")
  fi
fi

# Model segment (dim, appended to the ctx/session line)
model_part=""
[ -n "$model" ] && model_part="$(printf '\033[2m%s\033[0m' "$model")"

# Context usage segment (green/yellow/red based on usage) + session name
if [ -n "$used_pct" ]; then
  pct_int=${used_pct%.*}
  if [ "$pct_int" -ge 80 ] 2>/dev/null; then
    color='\033[31m'  # red
  elif [ "$pct_int" -ge 50 ] 2>/dev/null; then
    color='\033[33m'  # yellow
  else
    color='\033[32m'  # green
  fi
  ctx_part="$(printf "${color}ctx ${used_pct}%%\033[0m")"
  if [ -n "$session_name" ]; then
    ctx_part="${ctx_part} $(printf '\033[2m%s\033[0m' "$session_name")"
  fi
  ctx_part="${ctx_part}${model_part:+ $model_part}"
  parts+=("$ctx_part")
elif [ -n "$model_part" ]; then
  parts+=("$model_part")
fi

# Print each part on its own line
for part in "${parts[@]}"; do
  printf '%s\n' "$part"
done
