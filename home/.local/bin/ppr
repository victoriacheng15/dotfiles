#!/usr/bin/env bash
# GitHub PR Helper: Creates or updates a PR based on commit.md

set -euo pipefail

COMMIT_FILE="commit.md"

if [[ ! -f "$COMMIT_FILE" ]]; then
    echo "❌ Error: $COMMIT_FILE not found in current directory."
    exit 1
fi

# Parse arguments: extract --dry-run and collect other flags
dry_run=false
passthrough_args=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            dry_run=true
            shift
            ;;
        *)
            passthrough_args+=("$1")
            shift
            ;;
    esac
done

# Automatically detect the base branch (closest local ancestor branch)
current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
base_branch="main"
if [[ -n "$current_branch" ]]; then
    max_date=0
    for branch in $(git for-each-ref --format='%(refname:short)' refs/heads/); do
        if [[ "$branch" != "$current_branch" ]]; then
            base_commit=$(git merge-base "$current_branch" "$branch" 2>/dev/null || true)
            if [[ -n "$base_commit" ]]; then
                commit_date=$(git show -s --format=%ct "$base_commit" 2>/dev/null || echo 0)
                if [[ "$commit_date" -gt "$max_date" ]]; then
                    max_date=$commit_date
                    base_branch=$branch
                fi
            fi
        fi
    done
fi

# Check if --base was already provided in the arguments
base_provided=false
if [[ ${#passthrough_args[@]} -gt 0 ]]; then
    for arg in "${passthrough_args[@]}"; do
        if [[ "$arg" == "--base" ]]; then
            base_provided=true
            break
        fi
    done
fi

# Create temp file for body and ensure cleanup
BODY_FILE=$(mktemp)
trap 'rm -f "$BODY_FILE"' EXIT

# Extract body: from '### Summary' to just before '## Execution Commands'
awk '/### Summary/,/## Execution Commands/ { if (!/## Execution Commands/) print }' "$COMMIT_FILE" > "$BODY_FILE"

# Extract title from the git commit command line in commit.md
TITLE=$(grep "git commit -m" "$COMMIT_FILE" | sed 's/.*-m "\(.*\)".*/\1/')

if [[ "$dry_run" == true ]]; then
    echo "--- Extracted PR Body ---"
    cat "$BODY_FILE"
    echo "-------------------------"
    if gh pr view >/dev/null 2>&1; then
        echo "🔍 DRY RUN: gh pr edit --body-file <temp_file> ${passthrough_args[*]:-}"
    else
        create_args=("${passthrough_args[@]}")
        if [[ "$base_provided" == false ]]; then
            create_args+=("--base" "$base_branch")
        fi
        echo "🔍 DRY RUN: gh pr create --title \"$TITLE\" --body-file <temp_file> ${create_args[*]:-}"
    fi
    exit 0
fi

if gh pr view >/dev/null 2>&1; then
    echo "🔄 Existing PR found. Updating body..."
    gh pr edit --body-file "$BODY_FILE" "${passthrough_args[@]}"
else
    echo "🚀 Creating new PR: $TITLE (targeting base: $base_branch)"
    create_args=("${passthrough_args[@]}")
    if [[ "$base_provided" == false ]]; then
        create_args+=("--base" "$base_branch")
    fi
    gh pr create --title "$TITLE" --body-file "$BODY_FILE" "${create_args[@]}"
fi
