#!/usr/bin/env python3
"""Write immutable build identity; published builds must come from a clean commit."""
import json
import pathlib
import re
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[1]
control = (root / "control").read_text()
version = re.search(r"^Version:\s*(\S+)\s*$", control, re.M).group(1)
match = re.fullmatch(r"(\d+\.\d+\.\d+)-(\d+)", version)
if not match:
    raise SystemExit("Package version must include a numeric build revision, e.g. 2.4.7-1")
commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
dirty = subprocess.check_output(["git", "status", "--porcelain", "--", "."], cwd=root, text=True).strip()
identity = commit + ("-dirty" if dirty else "")
published=subprocess.run(["git","rev-parse","--verify",f"refs/tags/v{version}^{{commit}}"],cwd=root,text=True,capture_output=True)
if published.returncode==0 and (published.stdout.strip()!=commit or dirty):
    raise SystemExit("This build number is already published. Fetch tags, run scripts/next_build.py, and commit the new revision before building.")
destination = pathlib.Path(sys.argv[1])
destination.parent.mkdir(parents=True, exist_ok=True)
values = {"BHRD_BUILD_VERSION": version, "BHRD_PRODUCT_VERSION": match[1],
          "BHRD_BUILD_REVISION": match[2], "BHRD_BUILD_COMMIT": identity}
destination.write_text("#pragma once\n" + "".join(f"#define {name} @{json.dumps(value)}\n" for name, value in values.items()))
print(f"Build identity: {version} / {identity}")
