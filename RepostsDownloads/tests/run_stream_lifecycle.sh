#!/bin/sh
set -eu
cd "$(dirname "$0")"
if [ -x /usr/bin/python3 ]; then
    /usr/bin/python3 run_stream_lifecycle.py
else
    python3 run_stream_lifecycle.py
fi
