#!/bin/sh
set -eu
cd "$(dirname "$0")"
BHRD_TEST_BINARY="$(mktemp -t bhrd-host-view-tests)"
trap 'rm -f "$BHRD_TEST_BINARY"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -I HostFixtures \
 -framework Foundation -framework CoreGraphics -framework QuartzCore \
 ../BHRDShareVisibleData.m ../BHRDRepostAuthor.m ../BHRDRepostAuthorRows.m \
 ../BHRDSharePost.m ../BHRDMediaResolver.m ../BHRDRepostModel.m \
 HostFixtures/ViewGraph.m HostAuthorIntegrationTests.m -o "$BHRD_TEST_BINARY"
"$BHRD_TEST_BINARY"
