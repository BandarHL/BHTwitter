#!/bin/bash

# Configuration
REPO="nyathea/NeoFreeBird-BHTwitter"
BRANCH="master"
RUN_ID="14766098921"

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
            # Get all releases and filter for drafts using jq
            latest_draft=$(gh api /repos/$REPO/releases --jq '[.[] | select(.draft==true)] | first')
            
            if [ ! -z "$latest_draft" ]; then
                echo "Found draft release!"
                # Extract useful information from the draft release
                release_name=$(echo $latest_draft | jq -r '.name')
                release_tag=$(echo $latest_draft | jq -r '.tag_name')
                release_url=$(echo $latest_draft | jq -r '.html_url')
                assets_url=$(echo $latest_draft | jq -r '.assets_url')
                
                echo "Release Name: $release_name"
                echo "Tag: $release_tag"
                echo "URL: $release_url"
                
                # List assets if any
                echo "Assets:"
                echo $latest_draft | jq -r '.assets[] | "- \(.name): \(.browser_download_url)"'
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
