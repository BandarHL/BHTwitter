#!/bin/sh
set -eu
cd "$(dirname "$0")"
BHRD_SAVE_TEST="$(mktemp -t xsuixin-photo-save)"
trap 'rm -f "$BHRD_SAVE_TEST"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -I HostFixtures -framework Foundation -framework ImageIO -framework CoreGraphics \
  ../BHRDPhotoLibrarySave.m ../BHRDPhotoCopyData.m HostFixtures/Photos.m PhotoSave246Tests.m -o "$BHRD_SAVE_TEST"
"$BHRD_SAVE_TEST"
