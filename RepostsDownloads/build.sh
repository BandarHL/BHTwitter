#!/bin/sh
set -eu
cd "$(dirname "$0")"
: "${THEOS:?Please set THEOS to the Theos installation directory}"
if command -v gmake >/dev/null 2>&1; then
    BHRD_MAKE=gmake
else
    BHRD_MAKE=make
fi
"$BHRD_MAKE" clean
mkdir -p .theos/xsuixin-build
python3 scripts/write_build_info.py .theos/xsuixin-build/BHRDGeneratedBuildInfo.h
exec "$BHRD_MAKE" package THEOS_PACKAGE_SCHEME=rootless FINALPACKAGE=1 "$@"
