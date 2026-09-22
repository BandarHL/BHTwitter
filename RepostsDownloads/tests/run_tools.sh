#!/bin/sh
set -eu
cd "$(dirname "$0")"
BHRD_TEST_BINARY="$(mktemp -t bhrd-tools-tests)"
trap 'rm -f "$BHRD_TEST_BINARY"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -I HostFixtures -framework Foundation -framework ImageIO \
 ../BHRDPhotoCopyData.m ../BHRDPhotoClipboard.m ../BHRDFileNaming.m \
 HostFixtures/Clipboard.m Tools235Tests.m -o "$BHRD_TEST_BINARY"
"$BHRD_TEST_BINARY"
