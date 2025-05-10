#!/bin/bash

# Configuration
REPO="nyathea/NeoFreeBird-BHTwitter"
RUN_ID="14766098921"
BRANCH="master"

# Set default repository
gh repo set-default $REPO

# Add and commit changes
echo "Adding and committing changes..."
git add .
DATETIME=$(date -u "+%Y-%m-%d %H:%M:%S UTC")
git commit -m "Update: $DATETIME"

# Push to remote repository
echo "Pushing changes to remote..."
git push origin $BRANCH

# Function to stream specific job logs
stream_build_logs() {
    local run_id=$1
    echo "Streaming Build Package logs..."
    echo "----------------------------------------"
    
    # Get job ID for the Build Package job
    job_id=$(gh run view $run_id --json jobs -q '.jobs[] | select(.name=="Build Package") | .databaseId')
    
    if [ ! -z "$job_id" ]; then
        # Stream the specific job logs
        gh run view --job $job_id --log | grep -v "^$" | while IFS= read -r line; do
            if [[ $line == *"Build Package"* ]] || [ "$printing" = true ]; then
                printing=true
                echo "$line"
            fi
        done
    else
        echo "Waiting for Build Package job to start..."
    fi
}

# Rerun the workflow
echo "Starting workflow rerun..."
gh run rerun $RUN_ID

# Function to check workflow status
check_status() {
    status=$(gh run view $RUN_ID --json status -q .status)
    echo "Current status: $status"
    
    while [ "$status" = "in_progress" ] || [ "$status" = "queued" ]; do
        if [ "$status" = "in_progress" ]; then
            stream_build_logs $RUN_ID
        fi
        sleep 15  # Increased to 15 seconds to reduce spam
        status=$(gh run view $RUN_ID --json status -q .status)
        echo -e "\nCurrent status: $status"
    done
    
    if [ "$status" = "completed" ]; then
        conclusion=$(gh run view $RUN_ID --json conclusion -q .conclusion)
        echo "Workflow finished with conclusion: $conclusion"
        
        # Get final logs
        echo "Final Build Package logs:"
        stream_build_logs $RUN_ID
        
        if [ "$conclusion" = "success" ]; then
            echo "Workflow succeeded! Checking for draft release..."
            latest_draft=$(gh api /repos/$REPO/releases --jq '[.[] | select(.draft==true)] | first')
            
            if [ ! -z "$latest_draft" ]; then
                echo "Found draft release!"
                release_name=$(echo $latest_draft | jq -r '.name')
                release_tag=$(echo $latest_draft | jq -r '.tag_name')
                release_url=$(echo $latest_draft | jq -r '.html_url')
                
                echo "Release Name: $release_name"
                echo "Tag: $release_tag"
                echo "URL: $release_url"
                
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