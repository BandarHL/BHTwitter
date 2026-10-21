#!/bin/sh
set -eu
cd "$(dirname "$0")"
BHRD_EXPORT_TEST="$(mktemp -t bhrd-export-tests)"
trap 'rm -f "$BHRD_EXPORT_TEST"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation DiagnosticExportTests.m -o "$BHRD_EXPORT_TEST"
"$BHRD_EXPORT_TEST"
