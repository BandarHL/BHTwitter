#!/usr/bin/env python3
"""Verify rootless metadata, Mach-O deployment target and every signed code page."""
import argparse
import hashlib
import pathlib
import plistlib
import struct
import subprocess
import tempfile


def check(condition, message):
    if not condition:
        raise SystemExit(message)


def verify(package, version):
    for key, expected in [("Package", "com.caun.bhtwitter.repostsdownloads"), ("Version", version), ("Architecture", "iphoneos-arm64")]:
        value = subprocess.check_output(["dpkg-deb", "-f", str(package), key], text=True).strip()
        check(value == expected, f"Unexpected {key}: {value}")
    dependencies = subprocess.check_output(["dpkg-deb", "-f", str(package), "Depends"], text=True)
    check("firmware (>= 15.0)" in dependencies and "mobilesubstrate" in dependencies, "Missing deployment dependencies")
    with tempfile.TemporaryDirectory(prefix="xsuixin-package-check-") as directory:
        subprocess.run(["dpkg-deb", "-x", str(package), directory], check=True)
        root = pathlib.Path(directory)
        prefix = root / "var/jb/Library/MobileSubstrate/DynamicLibraries"
        check(not (root / "Library").exists(), "Unexpected rootful installation path")
        dylib = prefix / "BHRD.dylib"
        data = dylib.read_bytes()
        raw_plist = (prefix / "BHRD.plist").read_bytes()
        # Theos preserves OpenStep format; convert using macOS plutil when necessary.
        try:
            filters = plistlib.loads(raw_plist)
        except plistlib.InvalidFileException:
            raw_plist = subprocess.check_output(["plutil", "-convert", "xml1", "-o", "-", str(prefix / "BHRD.plist")])
            filters = plistlib.loads(raw_plist)
        check(filters == {"Filter": {"Bundles": ["com.atebits.Tweetie2"]}}, "Unexpected injection scope")
        check(struct.unpack_from("<I", data)[0] == 0xFEEDFACF, "Not a thin 64-bit Mach-O")
        check(struct.unpack_from("<I", data, 4)[0] == 0x0100000C, "Not arm64")
        ncmds = struct.unpack_from("<I", data, 16)[0]
        pos = 32
        signature = None
        target = None
        for _ in range(ncmds):
            cmd, length = struct.unpack_from("<II", data, pos)
            check(length >= 8 and pos + length <= len(data), "Malformed load command")
            if cmd == 0x1D:
                signature = struct.unpack_from("<II", data, pos + 8)
            if cmd == 0x25:  # LC_VERSION_MIN_IPHONEOS
                target = struct.unpack_from("<I", data, pos + 8)[0]
            if cmd == 0x32:  # LC_BUILD_VERSION
                platform, target = struct.unpack_from("<II", data, pos + 8)
                check(platform == 2, "Not an iOS device binary")
            if cmd in (0xC, 0x80000018, 0x8000001F):
                offset = struct.unpack_from("<I", data, pos + 8)[0]
                name = data[pos + offset:pos + length].split(b"\0")[0].decode()
                check(name.startswith(("/System/", "/usr/lib/", "/var/jb/", "@rpath/")), f"Unexpected dylib dependency: {name}")
                if "substrate" in name.lower():
                    check(name.startswith(("/var/jb/", "@rpath/")), "Rootful substrate dependency")
            pos += length
        check(target == 0x000F0000, f"Unexpected minimum iOS version: {target}")
        check(signature is not None, "Missing code signature")
        offset, size = signature
        blob = data[offset:offset + size]
        magic, length, count = struct.unpack_from(">III", blob)
        check(magic == 0xFADE0CC0 and length <= len(blob), "Invalid signature superblob")
        pages = 0
        directories = 0
        for index in range(count):
            _, relative = struct.unpack_from(">II", blob, 12 + index * 8)
            if struct.unpack_from(">I", blob, relative)[0] != 0xFADE0C02:
                continue
            cd_length = struct.unpack_from(">I", blob, relative + 4)[0]
            cd = blob[relative:relative + cd_length]
            cd_version, _, hashes, _, special, slots, limit = struct.unpack_from(">IIIIIII", cd, 8)
            hash_size, hash_type, _, page_exponent = struct.unpack_from(">BBBB", cd, 36)
            if cd_version >= 0x20300 and not limit:
                limit = struct.unpack_from(">Q", cd, 56)[0]
            algorithm = {1: "sha1", 2: "sha256", 3: "sha256", 4: "sha384"}.get(hash_type)
            check(algorithm is not None and 0 < page_exponent < 20, "Unsupported signature hash/page format")
            page_size = 1 << page_exponent
            check(limit <= offset and slots == (limit + page_size - 1) // page_size, "Invalid signed range")
            for slot in range(slots):
                expected = cd[hashes + slot * hash_size:hashes + (slot + 1) * hash_size]
                actual = hashlib.new(algorithm, data[slot * page_size:min(limit, (slot + 1) * page_size)]).digest()[:hash_size]
                check(expected == actual, f"Invalid code hash in directory {index}, page {slot}")
            pages += slots
            directories += 1
        check(directories > 0, "Missing CodeDirectory")
        check(b"[XSuixinDiag]" not in data, "Diagnostic code found in release")
        check(b"avatar-diag.log" in data and b"BHRDDiagnosticsViewController" in data, "Missing default diagnostics and viewer/export UI")
        check(b"BHRDInstallAdRuntimeHooks" not in data and b"google_ad_request_blocked" not in data,
              "Unexpected SSP runtime implementation")
        check(b"showSSPAdWhenNoPromotedMetadata" not in data and b"photo-save-1" in data,
              "Missing photo saving revision or unexpected SSP override")
        check(b"openDetails" in data and b"showThis" not in data,
              "Missing detail navigation or obsolete inline expansion handler")
        check(b"BHRDPhotoSaveJob" in data and b"startSavePhoto" in data,
              "Missing full-screen photo saving service or tool action")
        print(f"PASS: {version} rootless arm64, iOS 15.0, X-only injection; {directories} CodeDirectories / {pages} signed pages verified")
    digest = hashlib.sha256(package.read_bytes()).hexdigest()
    print(f"SHA256 {digest}  {package.name}")
    return digest


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("package", type=pathlib.Path)
    parser.add_argument("--version", default="2.4.6")
    args = parser.parse_args()
    verify(args.package.resolve(), args.version)
