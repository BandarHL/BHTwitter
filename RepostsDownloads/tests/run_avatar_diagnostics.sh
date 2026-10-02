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
xcrun clang -fobjc-arc -Wall -Wextra -Werror -Wno-unused-parameter -I HostFixtures \
  -DBHRD_AVATAR_DIAGNOSTICS=1 -DBHRD_AVATAR_DIAGNOSTICS_TEST=1 \
  -framework Foundation -framework CoreGraphics -framework QuartzCore \
  ../BHRDAvatarDiagnostics.m ../BHRDAdFilter.m \
  HostFixtures/ViewGraph.m AdDiagnostics244Tests.m -o "$BHRD_AVATAR_TEST_DIR/ad-test"
"$BHRD_AVATAR_TEST_DIR/ad-test"
xcrun clang -fobjc-arc -Wall -Wextra -Werror -I HostFixtures \
  -DBHRD_AVATAR_DIAGNOSTICS=1 -DBHRD_AVATAR_DIAGNOSTICS_TEST=1 \
  -framework Foundation -framework CoreGraphics -framework QuartzCore -framework ImageIO \
  ../BHRDAvatarDiagnostics.m ../BHRDPhotoLibrarySave.m ../BHRDPhotoCopyData.m \
  HostFixtures/ViewGraph.m HostFixtures/Photos.m PhotoSave246Tests.m -o "$BHRD_AVATAR_TEST_DIR/photo-save-test"
"$BHRD_AVATAR_TEST_DIR/photo-save-test"
/usr/bin/python3 - "$BHRD_AVATAR_TEST_DIR/avatar-diag.log" <<'PY'
import json, pathlib, sys
events = [json.loads(line) for line in pathlib.Path(sys.argv[1]).read_text().splitlines()]
names = {e['event'] for e in events}
required = {'preview_resolved', 'model_shape', 'model_url', 'native_image_view', 'avatar_missing_url', 'avatar_request_start', 'avatar_response', 'avatar_assigned', 'avatar_cache_hit', 'avatar_retry_scheduled', 'avatar_retries_exhausted', 'overlay_state', 'avatar_field', 'native_avatar_poll_scheduled', 'native_avatar_candidate', 'native_avatar_assigned'}
assert required <= names, required - names
assert any(e['event'] == 'avatar_response' and not e['current'] for e in events)
assert any(e['event'] == 'ad_response_seen' and e.get('marker') is False for e in events)
assert any(e['event'] == 'ad_response_seen' and e.get('marker') is True for e in events)
assert any(e['event'] == 'ad_response_checked' and bool(e.get('changed')) for e in events)
assert any(e['event'] == 'repost_detail_navigation' and e.get('result') == 'native_row_selection' for e in events)
assert any(e['event'] == 'repost_detail_navigation' and e.get('result') == 'stale_or_unavailable_row' for e in events)
assert any(e['event'] == 'repost_detail_navigation' and e.get('result') == 'native_selection_unavailable' for e in events)
assert {'photo_save_authorization', 'photo_save_committed', 'photo_save_result'} <= names
assert any(e['event'] == 'photo_save_result' and bool(e.get('success')) for e in events)
assert any(e['event'] == 'photo_save_result' and not bool(e.get('success')) for e in events)
print('PASS: diagnostic file contains every avatar lifecycle stage and discarded callbacks')
print('PASS: rollback diagnostics observe clean and filtered responses without SSP runtime hooks')
PY
