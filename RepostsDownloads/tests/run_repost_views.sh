#!/bin/sh
set -eu
cd "$(dirname "$0")"
BHRD_REPOST_VIEW_TEST="$(mktemp -t bhrd-repost-views)"
trap 'rm -f "$BHRD_REPOST_VIEW_TEST"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -Wno-unused-parameter -I HostFixtures \
  -framework Foundation -framework CoreGraphics -framework QuartzCore \
  ../BHRDRepostModel.m ../BHRDRepostPresentation.m ../BHRDConversationScope.m \
  ../BHRDAdFilter.m ../BHRDContentFilter.m ../BHRDPreferences.m \
  HostFixtures/ViewGraph.m RepostPresentation241Tests.m -o "$BHRD_REPOST_VIEW_TEST"
"$BHRD_REPOST_VIEW_TEST"
