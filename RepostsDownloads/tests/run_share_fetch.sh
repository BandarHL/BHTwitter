#!/bin/sh
set -eu
cd "$(dirname "$0")"
BHRD_SHARE_FETCH_DIR="$(mktemp -d -t bhrd-share-fetch)"
BHRD_SHARE_SERVER=''
cleanup() {
    if [ -n "$BHRD_SHARE_SERVER" ]; then kill "$BHRD_SHARE_SERVER" 2>/dev/null || true; wait "$BHRD_SHARE_SERVER" 2>/dev/null || true; fi
    rm -rf "$BHRD_SHARE_FETCH_DIR"
}
trap cleanup EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation -framework CoreGraphics -framework ImageIO \
 ../BHRDShareImageFetch.m ../BHRDShareMediaQuality.m ShareImageFetchTests.m -o "$BHRD_SHARE_FETCH_DIR/tests"
/usr/bin/python3 share_image_server.py "$BHRD_SHARE_FETCH_DIR/port" > "$BHRD_SHARE_FETCH_DIR/server.log" 2>&1 &
BHRD_SHARE_SERVER=$!
BHRD_SHARE_RETRIES=0
while [ ! -s "$BHRD_SHARE_FETCH_DIR/port" ]; do
    BHRD_SHARE_RETRIES=$((BHRD_SHARE_RETRIES + 1))
    if [ "$BHRD_SHARE_RETRIES" -gt 50 ]; then cat "$BHRD_SHARE_FETCH_DIR/server.log"; exit 1; fi
    sleep 0.1
done
"$BHRD_SHARE_FETCH_DIR/tests" "http://127.0.0.1:$(cat "$BHRD_SHARE_FETCH_DIR/port")"
