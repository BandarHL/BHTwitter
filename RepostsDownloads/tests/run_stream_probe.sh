#!/bin/sh
set -eu
cd "$(dirname "$0")"
BHRD_PROBE_TEST="$(mktemp -t xsuixin-stream-probe)"
trap 'rm -f "$BHRD_PROBE_TEST"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation ../BHRDStreamArguments.m StreamProbeArgumentsTests.m -o "$BHRD_PROBE_TEST"
"$BHRD_PROBE_TEST"
