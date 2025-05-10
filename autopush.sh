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

# Function to get and filter build logs
get_build_logs() {
    local run_id=$1
    local logs
    
    # Get all logs
    logs=$(gh run view $run_id --log 2>/dev/null)
    if [ $? -eq 0 ] && [ ! -z "$logs" ]; then
        # Print section between "Build Package" and next job, excluding empty lines
        echo "$logs" | awk '
            /^Build Package/ {p=1; print; next}
            p==1 {
                if (/^Job / && !/Build Package/) {p=0; next}
                if (NF > 0) print
            }
        '
        return 0
    fi
    return 1
}

echo "Waiting for logs..."

# Main loop to check status and logs
while true; do
    status=$(gh run view $RUN_ID --json status -q .status 2>/dev/null)
    
    # Debug output
    echo "Current status: $status" >&2
    
    if [ "$status" = "completed" ]; then
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
        if [ ! -z "$logs" ]; then
            echo "$logs"
            break
        fi
    fi
    
    sleep 10
done