#!/bin/sh
set -eu
cd "$(dirname "$0")"
task_performance_dir="$(mktemp -d -t xsuixin-performance)"
trap 'rm -rf "$task_performance_dir"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation \
    ../BHRDPerformanceStats.m PerformanceMonitorTests.m -o "$task_performance_dir/tests"
"$task_performance_dir/tests"
