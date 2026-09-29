#!/bin/sh
set -eu
cd "$(dirname "$0")"
BHRD_VIDEO_AD_TEST="$(mktemp -t xsuixin-video-ads)"
trap 'rm -f "$BHRD_VIDEO_AD_TEST"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation ../BHRDAdFilter.m VideoAd244Tests.m -o "$BHRD_VIDEO_AD_TEST"
"$BHRD_VIDEO_AD_TEST"
