#!/bin/sh
set -eu
cd "$(dirname "$0")"
BHRD_TEST_BINARY="$(mktemp -t bhrd-acceptance-tests)"
BHRD_TEST_DIRECTORY="$(mktemp -d -t bhrd-acceptance-state)"
trap 'rm -f "$BHRD_TEST_BINARY"; rm -rf "$BHRD_TEST_DIRECTORY"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -DBHRD_ACCEPTANCE_TEST=1 -framework Foundation \
 ../BHRDAcceptance.m AcceptanceTests.m -o "$BHRD_TEST_BINARY"
BHRD_ACCEPTANCE_TEST_DIR="$BHRD_TEST_DIRECTORY" "$BHRD_TEST_BINARY"
