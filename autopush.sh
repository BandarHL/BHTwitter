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


# Rerun the workflow
echo "Starting workflow rerun..."
gh run rerun $RUN_ID

# Function to check workflow status
check_status() {
    status=$(gh run view $RUN_ID --json status -q .status)
    echo "Current status: $status"
    echo "Waiting for completion..."
    
    while [ "$status" = "in_progress" ] || [ "$status" = "queued" ]; do
        sleep 30  # Check every 30 seconds
        status=$(gh run view $RUN_ID --json status -q .status)
        echo "Current status: $status"
    done
    
    if [ "$status" = "completed" ]; then
        conclusion=$(gh run view $RUN_ID --json conclusion -q .conclusion)
        echo "Workflow finished with conclusion: $conclusion"
        
        if [ "$conclusion" = "success" ]; then
            echo "Workflow succeeded! Checking for draft release..."
            # Get the latest draft release
            latest_draft=$(gh release list --limit 1 --exclude-pre-releases --draft)
            if [ ! -z "$latest_draft" ]; then
                echo "Found draft release:"
                echo "$latest_draft"
                # You can add more actions here for the draft release
            else
                echo "No draft release found"
            fi
        else
            echo "Workflow failed or was cancelled"
        fi
    fi
}

# Monitor the workflow
check_status

