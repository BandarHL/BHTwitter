#!/bin/sh
set -eu
cd "$(dirname "$0")"
sh build.sh BHRD_AVATAR_DIAGNOSTICS=1 PACKAGE_VERSION=2.4.3+diag.1
cp packages/com.caun.bhtwitter.repostsdownloads_2.4.3+diag.1_iphoneos-arm64.deb packages/XSuixin_2.4.3_diag1_rootless.deb
python3 scripts/verify_deb.py packages/XSuixin_2.4.3_diag1_rootless.deb --version 2.4.3+diag.1 --avatar-diagnostics
cd packages
shasum -a 256 XSuixin_2.4.3_diag1_rootless.deb > XSuixin_2.4.3_diag1_rootless.deb.sha256
