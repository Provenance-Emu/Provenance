#!/bin/bash
# Check Copilot review status for open PRs
# Usage: ./scripts/check-pr-reviews.sh [pr_number ...]
# If no PR numbers given, checks all open PRs with pr/issue- prefix

REPO="Provenance-Emu/Provenance"

if [ $# -gt 0 ]; then
  PRS="$@"
else
  PRS=$(gh pr list --repo "$REPO" --state open --json number --jq '.[].number' 2>/dev/null)
fi

for pr in $PRS; do
  # Get latest commit time
  commit_time=$(gh api "repos/$REPO/pulls/$pr/commits" --jq 'last | .commit.committer.date' 2>/dev/null)

  # Get all copilot reviews
  review_info=$(gh api "repos/$REPO/pulls/$pr/reviews" 2>/dev/null | python3 -c "
import sys, json
reviews = json.load(sys.stdin)
copilot = [r for r in reviews if r['user']['login'] == 'copilot-pull-request-reviewer[bot]']
if not copilot:
    print('NO_REVIEW|0|none|')
    sys.exit()
last = copilot[-1]
review_id = last['id']
submitted = last['submitted_at']
body = last.get('body', '')
# Check if it's a real review or just a summary
import re
m = re.search(r'generated (\d+) comment', body)
has_reviewed_line = 'Copilot reviewed' in body or 'Reviewed changes' in body
unable = 'not able' in body.lower() or 'unable' in body.lower() or \"wasn't able\" in body.lower()
if m:
    print(f'HAS_ISSUES|{m.group(1)}|{submitted}|{review_id}')
elif unable:
    print(f'FAILED|0|{submitted}|{review_id}')
elif has_reviewed_line:
    print(f'CLEAN|0|{submitted}|{review_id}')
else:
    # Summary only — check if it has review comments via the review comments endpoint
    print(f'CHECK_COMMENTS|0|{submitted}|{review_id}')
" 2>/dev/null)

  state=$(echo "$review_info" | cut -d'|' -f1)
  count=$(echo "$review_info" | cut -d'|' -f2)
  review_time=$(echo "$review_info" | cut -d'|' -f3)
  review_id=$(echo "$review_info" | cut -d'|' -f4)

  # Check if review is stale (commit after review)
  is_stale=$(python3 -c "print('yes' if '$commit_time' > '$review_time' else 'no')" 2>/dev/null)

  # For CHECK_COMMENTS or any state, also check review-attached comments
  if [ -n "$review_id" ] && [ "$review_id" != "none" ]; then
    review_comments=$(gh api "repos/$REPO/pulls/$pr/reviews/$review_id/comments" --jq 'length' 2>/dev/null)
    if [ "$review_comments" -gt 0 ] 2>/dev/null && [ "$state" != "HAS_ISSUES" ]; then
      state="HAS_ISSUES"
      count="$review_comments"
    fi
  fi

  # Also check for pending review request
  requested=$(gh api "repos/$REPO/pulls/$pr" --jq '[.requested_reviewers[].login] | join(", ")' 2>/dev/null)

  # Output
  if [ -n "$requested" ]; then
    echo "PR #$pr | 🔄 REVIEW PENDING ($requested)"
  elif [ "$is_stale" = "yes" ]; then
    echo "PR #$pr | ⏳ STALE (commit $commit_time > review $review_time)"
  elif [ "$state" = "HAS_ISSUES" ]; then
    echo "PR #$pr | ❌ $count ISSUES — NEEDS FIXES"
    # Show the actual comments
    if [ -n "$review_id" ] && [ "$review_id" != "none" ]; then
      gh api "repos/$REPO/pulls/$pr/reviews/$review_id/comments" --jq '.[] | "  → \(.path | split("/") | last):\(.line // "?") — \(.body[0:150])"' 2>/dev/null
    fi
  elif [ "$state" = "CLEAN" ]; then
    echo "PR #$pr | ✅ CLEAN — MERGEABLE"
  elif [ "$state" = "FAILED" ]; then
    echo "PR #$pr | ⚠️  COPILOT COULDN'T REVIEW"
  elif [ "$state" = "NO_REVIEW" ]; then
    echo "PR #$pr | ❌ NO COPILOT REVIEW"
  else
    echo "PR #$pr | ❓ UNKNOWN (state=$state review=$review_time)"
  fi
done
