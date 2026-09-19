#!/bin/sh
set -eu
cd "$(dirname "$0")"
BHRD_TEST_BINARY="$(mktemp -t bhrd-betterx-tests)"
trap 'rm -f "$BHRD_TEST_BINARY"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -I HostFixtures \
 -framework Foundation -framework CoreGraphics -framework QuartzCore \
 ../BHRDAdFilter.m ../BHRDAdPresentation.m ../BHRDPreferences.m ../BHRDLayoutGeometry.m \
 HostFixtures/ViewGraph.m BetterXAdsTests.m -o "$BHRD_TEST_BINARY"
"$BHRD_TEST_BINARY"
