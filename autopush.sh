#!/bin/bash

REPO="nyathea/NeoFreeBird-BHTwitter"
RUN_ID="14766098921"
BRANCH="master"
CURRENT_DATE=$(date -u "+%Y-%m-%d %H:%M:%S")
JOB_NAME="Build BHTwitter"
DEB_URL="https://github.com/nyathea/NeoFreeBird-BHTwitter/releases/download/untagged-bb5061f2d51e14fea2c7/com.bandarhl.bhtwitter_5.0-1%2Bdebug_iphoneos-arm64.deb"
DEB_LOCAL="com.bandarhl.bhtwitter_5.0-1+debug_iphoneos-arm64.deb"
REMOTE_USER="root"
REMOTE_HOST="10.0.0.24"
REMOTE_PATH="/var/mobile"

gh repo set-default "$REPO"

git add .
git commit -m "Update: $CURRENT_DATE UTC"
git push origin "$BRANCH"

gh run rerun "$RUN_ID"

while true; do
    status=$(gh run view "$RUN_ID" --json status -q .status 2>/dev/null)
    [ "$status" = "completed" ] && break
    sleep 10
done

# Get the job ID for "Build BHTwitter"
job_id=$(gh run view "$RUN_ID" --json jobs -q '.jobs[] | select(.name=="Build BHTwitter") | .databaseId' 2>/dev/null)

if [ -n "$job_id" ]; then
    gh run view --job "$job_id" --log
else
    echo "Could not find Build BHTwitter job logs."
fi

conclusion=$(gh run view "$RUN_ID" --json conclusion -q .conclusion 2>/dev/null)
if [ "$conclusion" = "success" ]; then
    # Download the .deb
    echo "Downloading .deb package..."
    curl -L -o "$DEB_LOCAL" "$DEB_URL"

    # Copy .deb to device
    echo "Copying .deb to device..."
    scp "$DEB_LOCAL" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/"

    # SSH to device, install, remove, and respring
    echo "Installing package on device..."
    ssh "$REMOTE_USER@$REMOTE_HOST" << EOF
cd $REMOTE_PATH
dpkg -i "$DEB_LOCAL"
rm "$DEB_LOCAL"
sbreload
EOF

    echo "Done!"
else
    echo "Workflow did not succeed, aborting deployment."
fi