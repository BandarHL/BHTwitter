#!/bin/bash

# Configuration
REPO="nyathea/NeoFreeBird-BHTwitter"
BRANCH="master"  # Change this if you're using a different default branch
WORKFLOW_NAME="build.yml"  # Replace this with your actual workflow filename

# First, set the default repository
gh repo set-default $REPO

# Add all changes
git add .

# Get current UTC date time for commit message
DATETIME=$(date -u "+%Y-%m-%d %H:%M:%S UTC")
git commit -m "Update: $DATETIME"

# Push to remote repository
git push origin $BRANCH

# Trigger the workflow
gh workflow run $WORKFLOW_NAME
