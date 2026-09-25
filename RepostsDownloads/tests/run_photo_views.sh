#!/bin/sh
set -eu
cd "$(dirname "$0")"
BHRD_TEST_BINARY="$(mktemp -t bhrd-photo-view-tests)"
trap 'rm -f "$BHRD_TEST_BINARY"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -I HostFixtures \
 -framework Foundation -framework CoreGraphics -framework QuartzCore -framework ImageIO -framework AVFoundation \
 ../BHRDFullscreenContext.m ../BHRDFullscreenPhotoResolver.m ../BHRDPhotoCopyData.m ../BHRDMediaResolver.m \
 HostFixtures/ViewGraph.m PhotoResolverTests.m -o "$BHRD_TEST_BINARY"
"$BHRD_TEST_BINARY"
