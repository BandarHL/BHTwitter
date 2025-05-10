#!/bin/bash

# Configuration
REPO="nyathea/NeoFreeBird-BHTwitter"
RUN_ID="14766098921"
BRANCH="master"
CURRENT_DATE=$(date -u "+%Y-%m-%d %H:%M:%S")

# Set default repository
gh repo set-default $REPO

# Add and commit changes
git add .
git commit -m "Update: $CURRENT_DATE UTC"
git push origin $BRANCH

# Rerun the workflow first!
echo "Rerunning workflow..."
gh run rerun $RUN_ID

# Function to get build logs
get_build_logs() {
    local run_id=$1
    # Get job ID for Build Package job
    local job_info=$(gh run view $run_id --json jobs -q '.jobs[] | select(.name=="Build Package")')
    if [ ! -z "$job_info" ]; then
        local job_id=$(echo "$job_info" | jq -r '.databaseId')
        if [ ! -z "$job_id" ] && [ "$job_id" != "null" ]; then
            # Get logs specifically for this job
            gh run view --job $job_id --log
            return 0
        fi
    fi
    return 1
}

echo "Waiting for Build Package job to start..."

# Main loop to check status and logs
while true; do
    status=$(gh run view $RUN_ID --json status -q .status 2>/dev/null)
    
    if [ "$status" = "completed" ]; then
        echo "Workflow completed, getting final logs..."
        get_build_logs $RUN_ID
        
        conclusion=$(gh run view $RUN_ID --json conclusion -q .conclusion)
        if [ "$conclusion" = "success" ]; then
            latest_draft=$(gh api /repos/$REPO/releases --jq '[.[] | select(.draft==true)] | first')
            if [ ! -z "$latest_draft" ]; then
                echo -e "\nDraft release found:"
                echo "$latest_draft" | jq -r '"Name: \(.name)\nTag: \(.tag_name)\nURL: \(.html_url)"'
                echo -e "\nAssets:"
                echo "$latest_draft" | jq -r '.assets[] | "- \(.name): \(.browser_download_url)"'
            fi
        fi
        break
    elif [ "$status" = "in_progress" ]; then
        logs=$(get_build_logs $RUN_ID)
        if [ $? -eq 0 ] && [ ! -z "$logs" ]; then
            echo "$logs"
            # Keep monitoring until completion
            continue
        fi
    fi
    
    sleep 10
done