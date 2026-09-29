#!/bin/sh
set -eu
cd "$(dirname "$0")"
BHRD_SSP_TEST="$(mktemp -t xsuixin-ssp-ads)"
trap 'rm -f "$BHRD_SSP_TEST"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -Wno-unused-parameter -framework Foundation \
  ../BHRDAdRuntime.m ../BHRDAdFilter.m ../BHRDPreferences.m SSPAds245Tests.m -o "$BHRD_SSP_TEST"
"$BHRD_SSP_TEST"
