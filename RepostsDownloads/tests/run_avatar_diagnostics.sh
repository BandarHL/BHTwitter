#!/bin/sh
set -eu
cd "$(dirname "$0")"
BHRD_AVATAR_TEST_DIR="$(mktemp -d -t xsuixin-avatar-diag)"
export BHRD_AVATAR_TEST_DIR
trap 'rm -rf "$BHRD_AVATAR_TEST_DIR"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -Wno-unused-parameter -I HostFixtures \
  -DBHRD_AVATAR_DIAGNOSTICS=1 -DBHRD_AVATAR_DIAGNOSTICS_TEST=1 \
  -framework Foundation -framework CoreGraphics -framework QuartzCore \
  ../BHRDAvatarDiagnostics.m HostFixtures/ViewGraph.m AvatarDiagnosticsTests.m -o "$BHRD_AVATAR_TEST_DIR/logger-test"
"$BHRD_AVATAR_TEST_DIR/logger-test"
xcrun clang -fobjc-arc -Wall -Wextra -Werror -Wno-unused-parameter -I HostFixtures \
  -DBHRD_AVATAR_DIAGNOSTICS=1 -DBHRD_AVATAR_DIAGNOSTICS_TEST=1 \
  -framework Foundation -framework CoreGraphics -framework QuartzCore \
  ../BHRDAvatarDiagnostics.m ../BHRDRepostModel.m ../BHRDRepostPresentation.m ../BHRDConversationScope.m \
  ../BHRDAdFilter.m ../BHRDContentFilter.m ../BHRDPreferences.m \
  HostFixtures/ViewGraph.m RepostPresentation241Tests.m -o "$BHRD_AVATAR_TEST_DIR/views-test"
"$BHRD_AVATAR_TEST_DIR/views-test"
/usr/bin/python3 - "$BHRD_AVATAR_TEST_DIR/avatar-diag.log" <<'PY'
import json, pathlib, sys
events = [json.loads(line) for line in pathlib.Path(sys.argv[1]).read_text().splitlines()]
names = {e['event'] for e in events}
required = {'preview_resolved', 'model_shape', 'model_url', 'native_image_view', 'avatar_missing_url', 'avatar_request_start', 'avatar_response', 'avatar_assigned', 'avatar_cache_hit', 'avatar_retry_scheduled', 'avatar_retries_exhausted', 'overlay_state'}
assert required <= names, required - names
assert any(e['event'] == 'avatar_response' and not e['current'] for e in events)
print('PASS: diagnostic file contains every avatar lifecycle stage and discarded callbacks')
PY
