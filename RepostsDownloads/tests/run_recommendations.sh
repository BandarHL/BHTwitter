#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p ../.theos
xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation ../BHRDContentFilter.m ../BHRDPreferences.m ../BHRDConfirmationGate.m RecommendationsTests.m -o ../.theos/recommendation-tests
../.theos/recommendation-tests
