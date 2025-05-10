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


# Trigger the workflow with the required input parameter
gh workflow run $WORKFLOW_ID -f decrypted_ipa_url="https://github.com/actuallyaridan/NeoFreeBird/releases/download/1.0/NeoFreeBird-1.0-Twitter-10.94-rev3.ipa"
