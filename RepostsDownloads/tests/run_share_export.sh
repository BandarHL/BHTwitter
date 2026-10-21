#!/bin/sh
set -eu
cd "$(dirname "$0")"
BHRD_SHARE_EXPORT_TEST="$(mktemp -t bhrd-share-export)"
trap 'rm -f "$BHRD_SHARE_EXPORT_TEST"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -I HostFixtures -framework Foundation -framework ImageIO -framework CoreGraphics \
 ../BHRDShareExport.m ../BHRDPhotoClipboard.m ../BHRDPhotoLibrarySave.m ../BHRDPhotoCopyData.m ../BHRDPreferences.m ../BHRDSafety.m \
 HostFixtures/Photos.m HostFixtures/Clipboard.m ShareExportTests.m -o "$BHRD_SHARE_EXPORT_TEST"
"$BHRD_SHARE_EXPORT_TEST"
