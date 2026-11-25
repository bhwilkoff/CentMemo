#!/usr/bin/env python3
"""The built iPhone app must be able to start on the oldest iOS it promises (18).

A library the app needs outright that iOS 18 does not have stops it before its first line
runs, and no newer device shows it: libswiftWebKit did exactly that from 1.0.28 to 1.0.33
(seen on the iOS 18.5 simulator, 2026-11-25). Every Swift library needed outright must be
one that iOS 18 carries. Add a name here only after seeing the app start on iOS 18.

    tools/test_ios_libraries.py <path to CentMemo.app or a folder holding one>
"""
import re
import subprocess
import sys
from pathlib import Path

IOS18 = set("""Core CoreFoundation CoreLocation Dispatch ObjectiveC Observation UniformTypeIdentifiers
_Concurrency _StringProcessing os Foundation CoreGraphics Darwin simd XPC Synchronization QuartzCore
CoreImage Metal Accelerate OSLog Spatial _RegexParser""".split())


def needed(binary):
    out = subprocess.run(["otool", "-l", str(binary)], capture_output=True, text=True, check=True).stdout
    return re.findall(r"cmd LC_LOAD_DYLIB\n\s+cmdsize \d+\n\s+name /usr/lib/swift/libswift(\S+)\.dylib", out)


def main():
    root = Path(sys.argv[1])
    apps = [root] if root.suffix == ".app" else sorted(root.glob("**/Debug-iphoneos/CentMemo.app"), key=lambda p: p.stat().st_mtime)
    if not apps:
        sys.exit("BLIND: no built CentMemo.app under " + str(root))
    app = apps[-1]
    bad, seen = set(), 0
    for b in [app / "CentMemo", app / "CentMemo.debug.dylib"]:
        if b.exists():
            libs = needed(b)
            seen += len(libs)
            bad |= set(libs) - IOS18
    if not seen:
        sys.exit("BLIND: read no libraries from " + str(app))
    if bad:
        sys.exit(f"FAIL: {app.name} cannot start on iOS 18: it needs {', '.join(sorted('libswift' + b for b in bad))}")
    print(f"ok: {seen} Swift libraries, all in iOS 18 ({app})")


if __name__ == "__main__":
    main()
