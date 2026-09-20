#!/bin/sh
set -eu
cd "$(dirname "$0")"
BHRD_PHOTO_TEST_DIR="$(mktemp -d -t bhrd-photo-tests)"
BHRD_PHOTO_SERVER=''
cleanup() {
    if [ -n "$BHRD_PHOTO_SERVER" ]; then kill "$BHRD_PHOTO_SERVER" 2>/dev/null || true; wait "$BHRD_PHOTO_SERVER" 2>/dev/null || true; fi
    rm -rf "$BHRD_PHOTO_TEST_DIR"
}
trap cleanup EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation -framework ImageIO \
 ../BHRDPhotoCopyData.m PhotoCopyTests.m -o "$BHRD_PHOTO_TEST_DIR/tests"
python3 photo_server.py "$BHRD_PHOTO_TEST_DIR/port" > "$BHRD_PHOTO_TEST_DIR/server.log" 2>&1 &
BHRD_PHOTO_SERVER=$!
BHRD_PHOTO_RETRIES=0
while [ ! -s "$BHRD_PHOTO_TEST_DIR/port" ]; do
    BHRD_PHOTO_RETRIES=$((BHRD_PHOTO_RETRIES + 1))
    if [ "$BHRD_PHOTO_RETRIES" -gt 50 ]; then cat "$BHRD_PHOTO_TEST_DIR/server.log"; exit 1; fi
    sleep 0.1
done
"$BHRD_PHOTO_TEST_DIR/tests" "http://127.0.0.1:$(cat "$BHRD_PHOTO_TEST_DIR/port")"
