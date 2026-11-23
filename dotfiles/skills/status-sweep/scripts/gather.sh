#!/usr/bin/env bash
# Collect the facts for a status sweep of the current repo as one JSON document:
# open PRs (checks, review, unresolved threads, preview links), PRs merged or
# closed recently, git worktrees, and local branches worth cleaning up.
# Read-only. Usage: gather.sh [--all] [--days N]
#   --all     every open PR in the repo, not just yours
#   --days N  how far back to look for merged/closed PRs (default 3)
set -euo pipefail

author="@me"; days=3
while [ $# -gt 0 ]; do
  case "$1" in
    --all) author="" ;;
    --days) days="$2"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

root=$(git rev-parse --show-toplevel)
cd "$root"
repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
default=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)
git fetch --quiet --prune origin 2>/dev/null || true
since=$(date -u -v-"${days}"d +%Y-%m-%d 2>/dev/null || date -u -d "-${days} days" +%Y-%m-%d)

author_args=(); [ -n "$author" ] && author_args=(--author "$author")
fields=number,title,url,author,headRefName,headRefOid,baseRefName,isDraft,mergeable,mergeStateStatus,reviewDecision,updatedAt,statusCheckRollup,comments

# Hosts that are dashboards/assets, not something you can open and test.
not_preview='github\.com|vercel\.com|vercel\.link|vercel\.sh|netlify\.com/(api|img)|\.svg|\.png|avatar|shields\.io'

prs=$(gh pr list --state open --limit 100 "${author_args[@]}" --json "$fields" | jq -c '.[]')
open_json="[]"
while IFS= read -r pr; do
  [ -z "$pr" ] && continue
  n=$(jq -r .number <<<"$pr"); sha=$(jq -r .headRefOid <<<"$pr")

  # Preview links, two sources: deployments on the head commit (exact), and
  # URLs posted by preview bots in PR comments (branch aliases, other hosts).
  deploys=$(gh api "repos/$repo/deployments?sha=$sha&per_page=10" --jq '.[] | [.id, .environment] | @tsv' 2>/dev/null || true)
  dep_json="[]"
  while IFS=$'\t' read -r id env; do
    [ -z "${id:-}" ] && continue
    st=$(gh api "repos/$repo/deployments/$id/statuses?per_page=1" --jq '.[0] // {} | {state, url: (.environment_url // "")}' 2>/dev/null || echo '{}')
    dep_json=$(jq -c --arg env "$env" --argjson st "$st" '. + [{environment: $env} + $st]' <<<"$dep_json")
  done <<<"$deploys"
  bot_urls=$(jq -r '[.comments[] | select(.author.login | test("bot|vercel|netlify|cloudflare|render|railway|fly"; "i")) | .body] | last // ""' <<<"$pr" \
    | { grep -oE 'https://[^ )"<>]+' || true; } | { grep -vE "$not_preview" || true; } | sort -u | jq -R . | jq -sc .)

  threads=$(gh api graphql -f query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){reviewThreads(first:100){nodes{isResolved}}}}}' \
    -F o="${repo%/*}" -F r="${repo#*/}" -F n="$n" --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved|not)] | length' 2>/dev/null || echo null)

  slim=$(jq -c --argjson deps "$dep_json" --argjson bot "$bot_urls" --argjson threads "$threads" '
    {number, title, url, author: .author.login, branch: .headRefName, base: .baseRefName,
     draft: .isDraft, mergeable, mergeState: .mergeStateStatus, review: (if (.reviewDecision // "") == "" then "NONE" else .reviewDecision end),
     updatedAt, unresolvedThreads: $threads,
     checks: ([.statusCheckRollup[] | (.conclusion // .state // "PENDING")] as $s |
       {total: ($s|length),
        failing: [.statusCheckRollup[] | select((.conclusion // .state) as $c | $c=="FAILURE" or $c=="ERROR" or $c=="TIMED_OUT" or $c=="CANCELLED" or $c=="ACTION_REQUIRED") | (.name // .context)],
        pending: [.statusCheckRollup[] | select((.conclusion // .state // "PENDING") as $c | $c=="PENDING" or $c=="QUEUED" or $c=="IN_PROGRESS" or $c=="EXPECTED" or $c=="") | (.name // .context)]}),
     previews: {deployments: $deps, botLinks: $bot}}' <<<"$pr")
  open_json=$(jq -c --argjson p "$slim" '. + [$p]' <<<"$open_json")
done <<<"$prs"

recent=$(gh pr list --state all --limit 50 "${author_args[@]}" --search "updated:>=$since" \
  --json number,title,url,state,headRefName,mergedAt,closedAt \
  --jq '[.[] | select(.state != "OPEN")]')

worktrees=$(git worktree list --porcelain | awk -v RS= '{
    path=""; branch=""; for (i=1;i<=NF;i++) { if ($i=="worktree") path=$(i+1); if ($i=="branch") branch=$(i+1) }
    sub("refs/heads/","",branch); print path "\t" branch }' |
  while IFS=$'\t' read -r path branch; do
    dirty=$(git -C "$path" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    ahead=null; behind=null
    if [ -n "$branch" ] && git rev-parse --verify --quiet "origin/$branch" >/dev/null; then
      read -r ahead behind < <(git rev-list --left-right --count "$branch...origin/$branch")
    fi
    last=$(git -C "$path" log -1 --format=%cI 2>/dev/null || echo "")
    jq -nc --arg p "$path" --arg b "$branch" --argjson d "$dirty" --argjson a "${ahead:-null}" --argjson bh "${behind:-null}" --arg l "$last" \
      '{path:$p, branch:$b, dirtyFiles:$d, unpushed:$a, behindRemote:$bh, lastCommit:$l, onRemote: ($a != null)}'
  done | jq -sc .)

merged_branches=$(git branch --format='%(refname:short)' --merged "origin/$default" | { grep -vxE "$default|main|master" || true; } | jq -R . | jq -sc .)
gone_branches=$(git branch --format='%(refname:short) %(upstream:track)' | awk '$2=="[gone]"{print $1}' | jq -R . | jq -sc .)

jq -n --arg repo "$repo" --arg root "$root" --arg default "$default" --arg scope "${author:-all}" \
  --argjson open "$open_json" --argjson recent "$recent" --argjson wt "$worktrees" \
  --argjson merged "$merged_branches" --argjson gone "$gone_branches" \
  '{repo:$repo, root:$root, defaultBranch:$default, prScope:$scope, generatedAt:(now|todate),
    openPRs:$open, recentlyClosedPRs:$recent,
    worktrees: [$wt[] | . as $w | . + {pr: ([$open[] | select(.branch == $w.branch) | .number] | first), closedPR: ([$recent[] | select(.headRefName == $w.branch) | {number, state}] | first)}],
    localBranches:{mergedIntoDefault:$merged, upstreamGone:$gone}}'
