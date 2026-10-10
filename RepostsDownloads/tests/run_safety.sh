#!/bin/sh
set -eu
cd "$(dirname "$0")"
BHRD_SAFETY_TEST_DIR="$(mktemp -d -t xsuixin-safety)"
export BHRD_SAFETY_TEST_DIR
trap 'rm -rf "$BHRD_SAFETY_TEST_DIR"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -DBHRD_SAFETY_TEST=1 -framework Foundation \
  ../BHRDSafety.m ../BHRDRuntimeStatus.m ../BHRDPreferences.m SafetyStatusTests.m -o "$BHRD_SAFETY_TEST_DIR/test"
"$BHRD_SAFETY_TEST_DIR/test"
touch "$BHRD_SAFETY_TEST_DIR/disabled"
"$BHRD_SAFETY_TEST_DIR/test" cold
