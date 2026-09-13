#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p ../.theos/share-previews
xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation -framework CoreGraphics -framework CoreText -framework ImageIO \
  ../BHRDMediaResolver.m ../BHRDSharePost.m ../BHRDRepostAuthorRows.m ../BHRDShareRenderer.m ../BHRDShareTextCleanup.m ShareImageTests.m -o ../.theos/share-image-tests
../.theos/share-image-tests ../.theos/share-previews
xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation \
  ../BHRDMediaResolver.m ../BHRDSharePost.m ShareCompletenessTests.m -o ../.theos/share-completeness-tests
../.theos/share-completeness-tests

xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation \
  ../BHRDMediaResolver.m ../BHRDSharePost.m ../BHRDShareTextCleanup.m ShareTextCleanupTests.m -o ../.theos/share-cleanup-tests
../.theos/share-cleanup-tests
