#!/bin/sh
set -eu
cd "$(dirname "$0")"
BHRD_TEST_BINARY="$(mktemp -t bhrd-download-retention-tests)"
trap 'rm -f "$BHRD_TEST_BINARY"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation \
 ../BHRDPreferences.m ../BHRDSafety.m ../BHRDDownloadStore.m ../BHRDFileNaming.m \
 DownloadRetentionTests.m -o "$BHRD_TEST_BINARY"
"$BHRD_TEST_BINARY"
