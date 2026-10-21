#!/bin/sh
set -eu
cd "$(dirname "$0")"
BHRD_IDENTITY_TEST="$(mktemp -t bhrd-repost-identity)"
trap 'rm -f "$BHRD_IDENTITY_TEST"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation \
  ../BHRDRepostModel.m RepostIdentity241Tests.m -o "$BHRD_IDENTITY_TEST"
"$BHRD_IDENTITY_TEST"
