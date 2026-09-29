#!/bin/sh
set -eu
cd "$(dirname "$0")"
# Backward-compatible entry point; all packages now include file diagnostics.
exec sh build.sh "$@"
