#!/bin/sh
set -eu
cd "$(dirname "$0")"
BHRD_REPOST_ACCEPTANCE_DIR="$(mktemp -d -t bhrd-repost-acceptance)"
trap 'rm -rf "$BHRD_REPOST_ACCEPTANCE_DIR"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -Wno-unused-parameter -I HostFixtures \
 -DBHRD_AVATAR_DIAGNOSTICS=1 -DBHRD_AVATAR_DIAGNOSTICS_TEST=1 -DBHRD_ACCEPTANCE_TEST=1 -DBHRD_SAFETY_TEST=1 \
 -framework Foundation -framework CoreGraphics -framework QuartzCore \
 ../BHRDAvatarDiagnostics.m ../BHRDAcceptance.m ../BHRDRepostModel.m ../BHRDRepostPresentation.m \
 ../BHRDRuntimeStatus.m ../BHRDConversationScope.m ../BHRDAdFilter.m ../BHRDContentFilter.m \
 ../BHRDPreferences.m ../BHRDSafety.m HostFixtures/ViewGraph.m RepostAcceptanceTests.m \
 -o "$BHRD_REPOST_ACCEPTANCE_DIR/test"
BHRD_AVATAR_TEST_DIR="$BHRD_REPOST_ACCEPTANCE_DIR" BHRD_ACCEPTANCE_TEST_DIR="$BHRD_REPOST_ACCEPTANCE_DIR" BHRD_SAFETY_TEST_DIR="$BHRD_REPOST_ACCEPTANCE_DIR" "$BHRD_REPOST_ACCEPTANCE_DIR/test"
