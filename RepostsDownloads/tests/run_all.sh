#!/bin/sh
set -eu
cd "$(dirname "$0")"
for suite in run.sh run_share.sh run_quality_ads.sh run_recommendations.sh run_downloads.sh run_release.sh run_host_views.sh run_photos.sh run_photo_views.sh run_tools.sh; do
    sh "$suite"
done
python3 run_streams.py
