#!/usr/bin/env python3
"""Advance the Debian revision using both control and fetched release tags."""
import pathlib
import re
import subprocess

root=pathlib.Path(__file__).resolve().parents[1]
path=root/"control"
text=path.read_text()
match=re.search(r"^Version:\s*(\d+\.\d+\.\d+)-(\d+)\s*$",text,re.M)
if not match:
    raise SystemExit("Expected upstream version plus numeric revision")
product,current=match.group(1),int(match.group(2))
tags=subprocess.check_output(["git","tag","--list",f"v{product}-*"],cwd=root,text=True).splitlines()
released=[int(t.rsplit("-",1)[1]) for t in tags if re.fullmatch(rf"v{re.escape(product)}-\d+",t)]
revision=max([current]+released)+1
version=f"{product}-{revision}"
path.write_text(text[:match.start()]+"Version: "+version+text[match.end():])
print(version)
