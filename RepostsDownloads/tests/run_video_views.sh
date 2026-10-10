#!/bin/sh
set -eu
cd "$(dirname "$0")"
BHRD_VIDEO_VIEW_BINARY="$(mktemp -t bhrd-video-view-tests)"
trap 'rm -f "$BHRD_VIDEO_VIEW_BINARY"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -I HostFixtures \
 -framework Foundation -framework CoreGraphics -framework QuartzCore -framework AVFoundation \
 ../BHRDFullscreenContext.m ../BHRDFullscreenVideoResolver.m ../BHRDMediaResolver.m \
 ../BHRDFullscreenVideoPresence.m ../BHRDFullscreenVisibility.m \
 HostFixtures/ViewGraph.m FullscreenVideoViewTests.m -o "$BHRD_VIDEO_VIEW_BINARY"
"$BHRD_VIDEO_VIEW_BINARY"
