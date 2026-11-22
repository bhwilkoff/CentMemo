#!/usr/bin/env python3
"""Design screenshots: every screen, on every phone, every display.

For design work (docs/design/STORY-DESIGN-BRIEF.md D3): opens each screen of the
installed DEBUG build through the launch doors, signed in as the synthetic owner,
and captures EVERY display of each device while CentMemo is in front. The iPhone
Duo has two: XCUITest only sees the outer one, black while the phone is open, so
this asks devicectl for each display by id (Ear Drama docs/research/IPHONE-DUO.md).
Flat-color frames (a display that is off) are deleted and named, never kept as
evidence. Frames are taken only while the app is running: what else is on the
owner's screen is not ours to photograph.

Install first (python3 tools/ios_uitest.py --device <d> --only TabSmokeUITests
builds and installs). Then:

    python3 tools/design_shots.py                       # iphone + duo, every screen
    python3 tools/design_shots.py --device duo --screen story
    python3 tools/design_shots.py --env APP_FAIL_NETWORK=offline

Frames land in build/design/<date>/<device>-<screen>-<display>.png.
"""
import argparse
import json
import re
import sys
import time
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import app_config  # noqa: E402
import apple_device as ad  # noqa: E402
import bench  # noqa: E402
import devlease  # noqa: E402
import frame_blind  # noqa: E402
from ios_uitest import displays  # noqa: E402

SCREENS = ["unexamined", "ledger", "story", "settings"]
OUT = app_config.REPO / "build" / "design" / date.today().isoformat()


def owner_env():
    users = json.loads((Path.home() / ".centmemo" / "test-users.json").read_text())
    return {"APP_TEST_EMAIL": users["owner"]["email"], "APP_TEST_PASSWORD": users["owner"]["password"]}


def shoot(name, extra_env, screens, settle):
    entry = bench.require(name, platforms=("ios", "ipados"))
    udid = entry["udid"]
    ids = displays(udid) or [None]
    kept = []
    with devlease.hold([bench.lease_name(entry)], task="design_shots", wait=300):
        for screen in screens:
            env = {**owner_env(), **app_config.DOOR_DEFAULTS, "APP_START_TAB": screen, **extra_env}
            ok, out = ad.launch(udid, app_config.APPLE_BUNDLE_ID, env=env)
            if not ok:
                print(f"FAIL {name}/{screen}: launch refused: {out}")
                continue
            time.sleep(settle)
            for i, did in enumerate(ids):
                dest = OUT / f"{name}-{screen}-{i}.png"
                if ad.app_alive(udid) is not True:
                    print(f"SKIP {name}/{screen}/display {i}: CentMemo is not running")
                    continue
                args = ["device", "capture", "screenshot", "--device", udid, "--destination", str(dest)]
                if did:
                    args += ["--display-unique-id", did]
                r = ad.devicectl(*args)
                if ad.app_alive(udid) is not True:
                    dest.unlink(missing_ok=True)
                    print(f"SKIP {name}/{screen}/display {i}: deleted, CentMemo was not in front after the capture")
                    continue
                if not dest.exists():
                    print(f"FAIL {name}/{screen}/display {i}: capture failed: {(r.stdout + r.stderr).strip()[-160:]}")
                elif frame_blind.is_blind(dest):
                    dest.unlink()
                    print(f"     {name}/{screen}/display {i}: off (one flat color), dropped")
                else:
                    print(f"PASS {name}/{screen}/display {i}: {dest}")
                    kept.append(dest)
        ad.terminate_verified(udid)
    return kept


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--device", action="append", help="bench name; default iphone and duo")
    ap.add_argument("--screen", action="append", choices=SCREENS)
    ap.add_argument("--env", action="append", default=[], help="KEY=VALUE door for every launch")
    ap.add_argument("--settle", type=float, default=7)
    a = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    extra = dict(e.split("=", 1) for e in a.env)
    kept = []
    for d in a.device or ["iphone", "duo"]:
        kept += shoot(d, extra, a.screen or SCREENS, a.settle)
    print(f"{len(kept)} frame(s) in {OUT}")
    return 0 if kept else 1


if __name__ == "__main__":
    sys.exit(main())
