#!/bin/bash

# Configuration
REPO="nyathea/NeoFreeBird-BHTwitter"
BRANCH="master"

# Add all changes
git add .

# Get current UTC date time for commit message
DATETIME=$(date -u "+%Y-%m-%d %H:%M:%S UTC")
git commit -m "Update: $DATETIME"

# Push to remote repository
git push origin $BRANCH

# Trigger the workflow using GitHub CLI
gh workflow run "$(basename $(gh workflow view 14766098921 --json path -q .path))"
