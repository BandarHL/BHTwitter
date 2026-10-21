#!/bin/sh
set -eu
cd "$(dirname "$0")"
BHRD_HOME_VIEW_TEST="$(mktemp -t bhrd-home-views)"
trap 'rm -f "$BHRD_HOME_VIEW_TEST"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -Wno-unused-parameter -I HomeFixtures -I HostFixtures \
  -framework Foundation -framework CoreGraphics -framework QuartzCore \
  ../BHRDHomeHeader.m ../BHRDHomeHeaderView.m ../BHRDHomePaging.m ../BHRDPreferences.m ../BHRDSafety.m \
  HostFixtures/ViewGraph.m HomeFixtures/HomeViewGraph.m HomePagingViewTests.m -o "$BHRD_HOME_VIEW_TEST"
"$BHRD_HOME_VIEW_TEST"
