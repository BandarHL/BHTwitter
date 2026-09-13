#!/bin/sh
set -eu
cd "$(dirname "$0")"
BHRD_TEST_BINARY="$(mktemp -t bhrd-filter-tests)"
trap 'rm -f "$BHRD_TEST_BINARY"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation \
  ../BHRDRepostFilter.m RepostFilterTests.m -o "$BHRD_TEST_BINARY"
"$BHRD_TEST_BINARY"

xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation \
  ../BHRDPreferences.m ../BHRDSettingsList.m CustomizationTests.m -o "$BHRD_TEST_BINARY"
"$BHRD_TEST_BINARY"

xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation \
  ../BHRDPreferences.m ../BHRDRepostModel.m RepostModelTests.m -o "$BHRD_TEST_BINARY"
"$BHRD_TEST_BINARY"

xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation \
  ../BHRDRepostAuthorRows.m RepostAuthorTests.m -o "$BHRD_TEST_BINARY"
"$BHRD_TEST_BINARY"

xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation \
  ../BHRDFullscreenActionRouter.m FullscreenRouterTests.m -o "$BHRD_TEST_BINARY"
"$BHRD_TEST_BINARY"

xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation \
  ../BHRDHomeHeader.m HomeHeaderTests.m -o "$BHRD_TEST_BINARY"
"$BHRD_TEST_BINARY"

xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation -framework CoreGraphics \
  ../BHRDLayoutGeometry.m ../BHRDFullscreenVisibility.m ../BHRDPreferences.m LayoutTests.m -o "$BHRD_TEST_BINARY"
"$BHRD_TEST_BINARY"

xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation \
  ../BHRDMediaResolver.m MediaResolverTests.m -o "$BHRD_TEST_BINARY"
"$BHRD_TEST_BINARY"

xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation \
  ../BHRDPreferences.m ShareButtonTests.m -o "$BHRD_TEST_BINARY"
"$BHRD_TEST_BINARY"

xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation \
  ../BHRDConversationScope.m ../BHRDRepostFilter.m ConversationTests.m -o "$BHRD_TEST_BINARY"
"$BHRD_TEST_BINARY"
