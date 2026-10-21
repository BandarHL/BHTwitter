"""Run actual Logos layout bodies on the existing macOS view-graph fixture."""
import argparse
import pathlib
import re
import subprocess
import tempfile

tests = pathlib.Path(__file__).resolve().parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--source", type=pathlib.Path, default=tests.parent / "Tweak.x")
args = parser.parse_args()
source = args.source.read_text()


def braced(text, start):
    """Return one C function/method including its balanced body."""
    opening = text.index("{", start)
    depth = 1
    for index in range(opening + 1, len(text)):
        depth += (text[index] == "{") - (text[index] == "}")
        if depth == 0:
            return text[start:index + 1]
    raise ValueError("Unterminated inline hook body")


# Accept the previous helper too so --source can prove the reported regression.
helper = re.search(r"static void (?:BHRDRegisterInlineMediaSource|BHRemoveExtraFullscreenDownloadButtons)\(UIView \*actionsView\)", source)
if not helper:
    raise ValueError("Missing inline registration helper; update the test extractor")
parts = [braced(source, helper.start())]
for name in ("TTAStatusInlineActionsView", "T1StatusInlineActionsView"):
    hook = re.search(r"%hook " + name + r"\b(.*?)%end", source, re.S)
    if not hook:
        raise ValueError(f"Missing {name} hook")
    method = braced(hook[1], hook[1].index("- (void)layoutSubviews"))
    method = method.replace("%orig", "[super layoutSubviews]")
    parts.append(f"@implementation {name}\n{method}\n@end")

with tempfile.TemporaryDirectory(prefix="bhrd-inline-download-") as folder:
    generated = pathlib.Path(folder)
    (generated / "InlineDownloadHooks.generated.h").write_text("\n".join(parts))
    binary = generated / "inline-download-tests"
    subprocess.run([
        "xcrun", "clang", "-fobjc-arc", "-Wall", "-Wextra", "-Werror",
        "-Wno-unused-parameter",  # The previous helper has unused block args.
        "-I", str(tests / "HostFixtures"), "-I", str(generated),
        "-include", str(tests / "InlineActionsFixture.h"),
        "-framework", "Foundation", "-framework", "CoreGraphics", "-framework", "QuartzCore",
        str(tests.parent / "BHRDInlineLayout.m"), str(tests.parent / "BHRDLayoutGeometry.m"),
        str(tests.parent / "BHRDMediaResolver.m"), str(tests / "HostFixtures/ViewGraph.m"),
        str(tests / "InlineDownloadHooksTests.m"), "-o", str(binary),
    ], check=True)
    subprocess.run([str(binary)], check=True)
