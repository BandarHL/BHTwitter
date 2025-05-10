#!/bin/bash

# Configuration
REPO="nyathea/NeoFreeBird-BHTwitter"
BRANCH="master"
WORKFLOW_ID="14766098921"

# default repository
gh repo set-default $REPO

# Add all changes
git add .

# Get current UTC date time for commit message
DATETIME=$(date -u "+%Y-%m-%d %H:%M:%S UTC")
git commit -m "Update: $DATETIME"

# Push to remote repository
git push origin $BRANCH

# Trigger the workflow using the same workflow as the previous run
gh workflow run $(gh api /repos/$REPO/actions/runs/$WORKFLOW_ID --jq .workflow_id)
