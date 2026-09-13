#!/bin/sh
set -eu
cd "$(dirname "$0")"
BHRD_TEST_DIR="$(mktemp -d -t bhrd-download-tests)"
BHRD_SERVER_PID=''
cleanup() {
  if [ -n "$BHRD_SERVER_PID" ]; then kill "$BHRD_SERVER_PID" 2>/dev/null || true; fi
  rm -rf "$BHRD_TEST_DIR"
}
trap cleanup EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation \
  ../BHRDTaskState.m ../BHRDDownload.m DownloadLifecycleTests.m -o "$BHRD_TEST_DIR/tests"
python3 download_server.py "$BHRD_TEST_DIR/port" > "$BHRD_TEST_DIR/server.log" 2>&1 &
BHRD_SERVER_PID=$!
BHRD_RETRIES=0
while [ ! -s "$BHRD_TEST_DIR/port" ]; do
  BHRD_RETRIES=$((BHRD_RETRIES + 1))
  if [ "$BHRD_RETRIES" -gt 50 ]; then cat "$BHRD_TEST_DIR/server.log"; exit 1; fi
  sleep 0.1
done
"$BHRD_TEST_DIR/tests" "http://127.0.0.1:$(cat "$BHRD_TEST_DIR/port")"
