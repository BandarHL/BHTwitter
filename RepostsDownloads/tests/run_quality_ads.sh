#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p ../.theos
xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation -framework CoreGraphics -framework ImageIO ../BHRDShareMediaQuality.m ../BHRDAdFilter.m ../BHRDPreferences.m ../BHRDSafety.m QualityAdsTests.m -o ../.theos/quality-ads-tests
../.theos/quality-ads-tests
