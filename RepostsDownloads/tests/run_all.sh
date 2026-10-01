#!/bin/sh
set -eu
cd "$(dirname "$0")"
for suite in run.sh run_share.sh run_quality_ads.sh run_video_ads.sh run_recommendations.sh run_downloads.sh run_release.sh run_host_views.sh run_photos.sh run_photo_views.sh run_tools.sh run_repost_identity.sh run_repost_views.sh run_avatar_diagnostics.sh; do
    sh "$suite"
done
if [ -x /usr/bin/python3 ]; then
    /usr/bin/python3 run_streams.py
else
    python3 run_streams.py
fi
