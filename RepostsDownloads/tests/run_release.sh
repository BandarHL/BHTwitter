#!/bin/sh
set -eu
cd "$(dirname "$0")"
BHRD_TEST_BINARY="$(mktemp -t bhrd-release-tests)"
trap 'rm -f "$BHRD_TEST_BINARY"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation \
 ../BHRDRepostModel.m ../BHRDAdFilter.m ../BHRDSharePost.m ../BHRDMediaResolver.m \
 ../BHRDShareRenderState.m ../BHRDHomeHeader.m ../BHRDTaskState.m ../BHRDStreamArguments.m \
 ../BHRDDownloadStore.m Release230Tests.m -o "$BHRD_TEST_BINARY"
"$BHRD_TEST_BINARY"
