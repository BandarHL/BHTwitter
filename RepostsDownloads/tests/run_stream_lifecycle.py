"""Run the complete production StreamJob against native-engine/UI host fixtures."""
import pathlib
import subprocess
import tempfile

tests = pathlib.Path(__file__).resolve().parent
source_path = tests.parent / "BHRDStreamJob.m"
source = source_path.read_text()
# Only the two UIKit-facing dependency imports are substituted; no lifecycle
# implementation is extracted, rewritten, or recreated in the fixture.
for header in ("BHRDDownloadProgress.h", "BHRDManager.h"):
    directive = f'#import "{header}"'
    if source.count(directive) != 1:
        raise ValueError(f"Unexpected platform dependency: {header}")
    source = source.replace(directive, '#import "StreamJobFixture.h"')
button = (tests.parent / "BHRDDownloadButton.m").read_text()
if "[BHRDStreamJob probeURL:url selectionStillCurrent:selectionStillCurrent completion:" not in button:
    raise ValueError("Download menu does not pass its live selection guard to FFprobe")

with tempfile.TemporaryDirectory(prefix="bhrd-stream-lifecycle-") as directory:
    generated = pathlib.Path(directory)
    implementation = generated / "StreamJob.generated.m"
    implementation.write_text(f'#line 1 "{source_path}"\n' + source)
    binary = generated / "stream-lifecycle-tests"
    subprocess.run([
        "xcrun", "clang", "-fobjc-arc", "-Wall", "-Wextra", "-Werror",
        "-DBHRD_AVATAR_DIAGNOSTICS=1", "-framework", "Foundation",
        "-I", str(tests), "-I", str(tests.parent), str(implementation),
        str(tests.parent / "BHRDTaskState.m"), str(tests.parent / "BHRDStreamArguments.m"),
        str(tests / "StreamJobFixture.m"), str(tests / "StreamJobLifecycleTests.m"),
        "-o", str(binary),
    ], check=True)
    subprocess.run([str(binary)], check=True)
