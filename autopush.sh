#!/bin/bash

REPO="nyathea/NeoFreeBird-BHTwitter"
RUN_ID="14766098921"
BRANCH="master"
CURRENT_DATE=$(date -u "+%Y-%m-%d %H:%M:%S")

# Set default repo for gh CLI
gh repo set-default "$REPO"

# Add and commit changes
git add .
git commit -m "Update: $CURRENT_DATE UTC"
git push origin "$BRANCH"

# Rerun the workflow
gh run rerun "$RUN_ID"

# Wait for workflow to complete
while true; do
    status=$(gh run view "$RUN_ID" --json status -q .status 2>/dev/null)
    [ "$status" = "completed" ] && break
    sleep 10
done

# Get the job ID for "Build Package"
job_id=$(gh run view "$RUN_ID" --json jobs -q '.jobs[] | select(.name=="Build Package") | .databaseId' 2>/dev/null)

if [ -n "$job_id" ]; then
    gh run view --job "$job_id" --log
else
    echo "Could not find Build Package job logs."
fi

# Optionally, show draft release info if successful
conclusion=$(gh run view "$RUN_ID" --json conclusion -q .conclusion 2>/dev/null)
if [ "$conclusion" = "success" ]; then
    latest_draft=$(gh api /repos/$REPO/releases --jq '[.[] | select(.draft==true)] | first' 2>/dev/null)
    if [ ! -z "$latest_draft" ]; then
        echo -e "\nDraft release found:"
        echo "$latest_draft" | jq -r '"Name: \(.name)\nTag: \(.tag_name)\nURL: \(.html_url)"'
        echo -e "\nAssets:"
        echo "$latest_draft" | jq -r '.assets[] | "- \(.name): \(.browser_download_url)"'
    fi
fi