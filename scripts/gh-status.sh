#!/usr/bin/env bash
# Quick status inspector for GitHub issues and PRs via gh CLI.
# Usage:
#   gh-status --issue 1643 1646 2143
#   gh-status --pr 5075 5058 5077
#   gh-status --repo owner/repo --issue 123

set -euo pipefail

REPO="${GH_REPO:-}"
MODE=""
ITEMS=()

usage() {
  cat <<EOF
Usage: gh-status [MODE] [--repo OWNER/REPO] [NUMBERS...]

Modes:
  --issue               Inspect one or more issue numbers
  --pr                  Inspect one or more PR numbers
  --repo OWNER/REPO     Target repository (defaults to current git repo or GH_REPO)
  -h, --help            Show this help message

Examples:
  gh-status --issue 1643 1646 2143
  gh-status --pr 5075 5058 5077
  gh-status --repo chaos-mesh/chaos-mesh --issue 1643
EOF
  exit "${1:-1}"
}

if [[ $# -eq 0 ]]; then
  usage 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)
      MODE="issue"
      shift
      ;;
    --pr)
      MODE="pr"
      shift
      ;;
    --repo)
      REPO="$2"
      shift 2
      ;;
    -h|--help)
      usage 0
      ;;
    *)
      ITEMS+=("$1")
      shift
      ;;
  esac
done

if [[ -z "$MODE" ]]; then
  echo "Error: Specify --issue or --pr."
  usage
fi

if [[ ${#ITEMS[@]} -eq 0 ]]; then
  echo "Error: Provide at least one issue or PR number."
  usage
fi

if [[ -z "$REPO" ]]; then
  REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
fi

if [[ -z "$REPO" ]]; then
  echo "Error: Could not detect repository. Use --repo OWNER/REPO or run inside a GitHub repository."
  exit 1
fi

echo "Repository: $REPO"
printf "%-8s %-10s %-50s %s\n" "TYPE" "STATE" "TITLE" "DETAILS"
printf "%s\n" "--------------------------------------------------------------------------------------------------------"

for num in "${ITEMS[@]}"; do
  if [[ "$MODE" == "issue" ]]; then
    data=$(gh issue view "$num" --repo "$REPO" --json state,title,comments 2>/dev/null || true)
    if [[ -z "$data" ]]; then
      printf "%-8s %-10s %-50s %s\n" "#$num" "NOT_FOUND" "-" "Could not fetch issue"
      continue
    fi
    state=$(jq -r '.state' <<< "$data")
    title=$(jq -r '.title' <<< "$data" | cut -c 1-48)
    last_comment_author=$(jq -r 'if (.comments | length) > 0 then .comments[-1].author.login else "none" end' <<< "$data")
    comment_count=$(jq -r '.comments | length' <<< "$data")
    details="comments: $comment_count (last: @$last_comment_author)"
    printf "%-8s %-10s %-50s %s\n" "#$num" "$state" "$title" "$details"

  elif [[ "$MODE" == "pr" ]]; then
    data=$(gh pr view "$num" --repo "$REPO" --json state,title,mergedAt,author 2>/dev/null || true)
    if [[ -z "$data" ]]; then
      printf "%-8s %-10s %-50s %s\n" "PR #$num" "NOT_FOUND" "-" "Could not fetch PR"
      continue
    fi
    state=$(jq -r '.state' <<< "$data")
    title=$(jq -r '.title' <<< "$data" | cut -c 1-48)
    author=$(jq -r '.author.login' <<< "$data")
    merged_at=$(jq -r '.mergedAt // empty' <<< "$data")
    if [[ -n "$merged_at" ]]; then
      details="by @$author (merged: ${merged_at:0:10})"
    else
      details="by @$author"
    fi
    printf "%-8s %-10s %-50s %s\n" "PR #$num" "$state" "$title" "$details"
  fi
done
