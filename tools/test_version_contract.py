#!/usr/bin/env python3
"""
AppVersion.xcconfig is the ONE version number — including on Android.

In a shipped app the Android build carried `versionName = "1.42.6"` under a
comment saying it "tracks the Apple apps (AppVersion.xcconfig)". Nothing read
that file, so the literal drifted 88 patch versions behind: for weeks an
Android user reporting a problem named a version family that no longer
existed, and a crash cluster could not be matched to the code that produced it.

The build now READS the file, which makes drift impossible by construction.
This guards the construction — someone typing a literal back in is exactly how
it happened the first time. (versionCode stays a literal: Play owns its
monotonic sequence, and play-release.yml bumps it.)

Run: python3 tools/test_version_contract.py   (exit 0 = pass; a repo with no
android/ module passes with a note)
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
fails = []


def check(ok, what, detail=""):
    print(f"  {'PASS' if ok else 'FAIL'}  {what}" + (f"  — {detail}" if detail and not ok else ""))
    if not ok:
        fails.append(what)


xc = (ROOT / "AppVersion.xcconfig").read_text()
m = re.search(r"^MARKETING_VERSION\s*=\s*(\S+)", xc, re.M)
check(m is not None, "AppVersion.xcconfig declares MARKETING_VERSION")
marketing = m.group(1) if m else ""

check(re.fullmatch(r"\d+\.\d+\.\d+", marketing) is not None,
      "MARKETING_VERSION is MAJOR.MINOR.PATCH", marketing)


def pair(text):
    v = re.search(r"^MARKETING_VERSION\s*=\s*(\S+)", text, re.M)
    b = re.search(r"^CURRENT_PROJECT_VERSION\s*=\s*(\S+)", text, re.M)
    return (v and v.group(1), b and b.group(1))


# CentMemo shipped TestFlight builds 1 to 17 all as "1.0" (Ben, 2026-11-24): the
# two numbers move together. Compares this file with the last one that differed.
def git(*a):
    return subprocess.run(["git", "-C", str(ROOT), *a], capture_output=True, text=True).stdout


now = pair(xc)
before = next((p for p in (pair(git("show", f"{h}:AppVersion.xcconfig"))
                           for h in git("log", "-5", "--format=%h", "--", "AppVersion.xcconfig").split())
               if p != now and p[0]), None)
if before:
    check(now[0] != before[0] and now[1] != before[1],
          "the version and the build number were bumped together", f"{before} -> {now}")
else:
    print("  SKIP  no earlier AppVersion.xcconfig in this checkout's history")

gradle_file = ROOT / "android/app/build.gradle.kts"
if not gradle_file.exists():
    print("  SKIP  no android/app/build.gradle.kts — this app has no Android module")
    sys.exit(1 if fails else 0)
gradle = gradle_file.read_text()

check(re.search(r"^\s*versionName\s*=\s*marketingVersion\b", gradle, re.M) is not None,
      "Android takes versionName from the shared file, not a literal")

# A literal would look like versionName = "1.2.3". Anything quoted is the bug.
lit = re.search(r'versionName\s*=\s*"', gradle)
check(lit is None, "...and no quoted versionName literal has crept back",
      lit.group(0) if lit else "")

check(re.search(r'rootProject\.file\("\.\./AppVersion\.xcconfig"\)', gradle) is not None,
      "...reading the file the Apple targets use")

# The read must FAIL rather than fall back: a default would restore the drift
# silently, which is the failure mode this whole file exists for.
check("error(" in gradle and "MARKETING_VERSION not found" in gradle,
      "a missing MARKETING_VERSION fails the build rather than defaulting")

print(f"\nmarketing version = {marketing}")
print(f"{len(fails)} failed" if fails else "all passed")
sys.exit(1 if fails else 0)
