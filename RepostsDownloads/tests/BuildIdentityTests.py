import pathlib
import shutil
import subprocess
import tempfile

source=pathlib.Path(__file__).resolve().parents[1]
def run(args,root,ok=True):
    p=subprocess.run(args,cwd=root,text=True,capture_output=True)
    assert (p.returncode==0)==ok,(args,p.stdout,p.stderr)
    return p.stdout
with tempfile.TemporaryDirectory(prefix="xsuixin-identity-") as folder:
    root=pathlib.Path(folder)
    scripts=root/"RepostsDownloads/scripts"; scripts.mkdir(parents=True)
    for name in ["write_build_info.py","next_build.py"]: shutil.copy(source/"scripts"/name,scripts/name)
    control=root/"RepostsDownloads/control"; control.write_text("Package: test\nVersion: 2.4.7-1\nArchitecture: iphoneos-arm64\n")
    (root/".gitignore").write_text(".build/\n")
    run(["git","init"],root); run(["git","config","user.name","Build test"],root); run(["git","config","user.email","build-test@example.invalid"],root)
    run(["git","add","."],root); run(["git","commit","-m","source"],root)
    head=run(["git","rev-parse","HEAD"],root).strip(); output=root/".build/info.h"
    run(["python3",str(scripts/"write_build_info.py"),str(output)],root)
    text=output.read_text(); assert head in text and "dirty" not in text and '@"2.4.7-1"' in text
    run(["git","tag","v2.4.7-1"],root)
    run(["python3",str(scripts/"write_build_info.py"),str(output)],root)
    (root/"RepostsDownloads/feature.txt").write_text("new code")
    run(["python3",str(scripts/"write_build_info.py"),str(output)],root,False)
    version=run(["python3",str(scripts/"next_build.py")],root).strip(); assert version=="2.4.7-2" and "Architecture:" in control.read_text()
    run(["git","add","."],root); run(["git","commit","-m","next"],root)
    run(["python3",str(scripts/"write_build_info.py"),str(output)],root)
    assert '@"2.4.7-2"' in output.read_text() and "dirty" not in output.read_text()
    run(["git","tag","v2.4.7-5"],root)
    assert run(["python3",str(scripts/"next_build.py")],root).strip()=="2.4.7-6"
print("PASS: build identity, immutable version and monotonic revision checks")
