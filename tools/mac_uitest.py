#!/usr/bin/env python3
"""The Mac's tap tier, through the real buttons, data left as found: a memo saved, read
back after a relaunch and removed; a purchase skipped and brought back; a place renamed
and given its statement name back.

Signs in as the synthetic owner through the DEBUG door, never as a person. Presses
controls by accessibility and by process id, so nothing comes to the front. Needs the
terminal's existing Accessibility permission; without it the run is BLIND, not a FAIL.

    /usr/bin/python3 tools/mac_uitest.py [--binary PATH]
"""
import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import app_config  # noqa: E402
import devlease  # noqa: E402
import macapp  # noqa: E402

REPO = Path(__file__).resolve().parent.parent
BINARY = REPO / "build/dd-mac/Build/Products/Debug/CentMemo.app/Contents/MacOS/CentMemo"
SHOTS = REPO / "build/qa/mac"
UNEXAMINED = "e5626ed0-b9f2-48a0-8df7-672ae6016a40"
ZOO = "a3b8c10c-68b8-4bfe-9380-c87b7015a49d"


class Failed(Exception):
    pass


def build_tool():
    src, out = REPO / "tools/mac_ax.swift", app_config.BIN_DIR / "mac_ax"
    if not out.exists() or out.stat().st_mtime < src.stat().st_mtime:
        out.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["swiftc", "-O", str(src), "-o", str(out)], check=True)
    return out


class App:
    def __init__(self, tool, binary, user, doors):
        self.tool = tool
        self.pid = macapp.launch(binary, {**app_config.DOOR_DEFAULTS, "APP_TEST_EMAIL": user["email"],
                                          "APP_TEST_PASSWORD": user["password"], "APP_WINDOW": "1180x800",
                                          "APP_APPEARANCE": "light", **doors})

    def ax(self, *args):
        try:
            r = subprocess.run([str(self.tool), str(self.pid), *args], capture_output=True, text=True, timeout=30)
        except subprocess.TimeoutExpired:  # a busy Mac: the app has not answered yet
            return 1, "", "BLIND: no answer in 30s"
        return r.returncode, r.stdout.strip(), r.stderr.strip()

    def do(self, *args):
        rc, out, err = self.ax(*args)
        if rc and "no windows" in err:  # nothing was pressed: the tool found no window
            time.sleep(3)
            rc, out, err = self.ax(*args)
        if rc:
            raise Failed(f"{args[:2]}: {err}")
        return out

    def wait(self, ident, want=None, seconds=90):
        end, last = time.time() + seconds, ""
        while time.time() < end:
            rc, out, err = self.ax("get", ident)
            last = out or err
            if rc == 0 and (want is None or want(out)):
                return out
            time.sleep(1)
        seen = SHOTS / "failed-tree.txt"
        seen.write_text(self.ax("dump")[1])
        raise Failed(f"{ident}: waited {seconds}s, last read {last!r}; the screen's controls are in {seen}")

    def quit(self):
        try:
            os.kill(self.pid, 15)
        except ProcessLookupError:
            pass
        time.sleep(1.5)


def memo_round_trip(open_app):
    note = f"Mac test memo {int(time.time())}"
    app, saved = open_app(), False
    try:
        before = app.wait("memo-editor")
        if before:
            raise Failed(f"the fixture already has a memo: {before!r}")
        if app.ax("get", "share-memo")[0] == 0:
            raise Failed("Share offered with no memo")
        app.do("type", "memo-editor", note)
        app.wait("memo-editor", lambda v: v == note, 40)
        app.do("press", "save-memo")
        app.wait("memo-status", lambda v: "Saved." in v, 40)
        saved = True
        app.wait("share-memo", seconds=40)
        app.wait("link-memo", seconds=40)
        print("PASS Share and Make a link are there right after Save")
        macapp.capture(app.pid, str(SHOTS / "memo-saved.png"))
        app.quit()
        app = open_app()
        app.wait("memo-editor", lambda v: v == note)
        print("PASS a memo saved on the Mac survives a relaunch")
    finally:
        if saved:
            app.do("clear", "memo-editor")
            app.wait("memo-editor", lambda v: v == "", 40)
            app.do("press", "save-memo")
            app.wait("memo-status", lambda v: "Memo removed." in v, 40)
            if app.ax("get", "share-memo")[0] == 0:
                raise Failed("Share still offered after the memo was removed")
            print("PASS and is removed again, and Share with it")
        app.quit()


def skip_round_trip(open_app):
    app = open_app()
    try:
        app.wait("memo-editor")
        listed = lambda: "King Soopers, Nov 17 · " in app.ax("dump")[1]  # noqa: E731
        if not listed():
            raise Failed("the fixture is not on Unexamined")
        app.do("press", "skip-event")
        try:
            app.wait("Bring back", seconds=40)
            time.sleep(3)
            if listed():
                raise Failed("a skipped purchase stayed on Unexamined")
            print("PASS Skip takes it off Unexamined")
        finally:
            app.do("press", "Bring back")
            app.wait("Skip", seconds=40)
            time.sleep(2)
        for _ in range(10):
            if listed():
                break
            time.sleep(1)
        else:
            raise Failed("Bring back did not return it to Unexamined")
        print("PASS Bring back returns it")
    finally:
        app.quit()


def rename_round_trip(open_app):
    app = open_app()
    try:
        app.wait("every-visit")
        app.do("press", "every-visit")
        app.wait("setting-summary", seconds=40)
        app.do("press", "setting-rename")
        if app.wait("sheet-field", seconds=40) != "Denver Zoo":
            raise Failed("the page is not Denver Zoo's, or it is already renamed")
        app.do("clear", "sheet-field")
        app.do("type", "sheet-field", "The Zoo")
        app.do("press", "action-button-1")
        app.wait("setting-summary", seconds=40)
        time.sleep(3)
        page = app.ax("dump")[1]
        app.do("press", "setting-rename")
        again = app.wait("sheet-field", seconds=40)
        app.do("press", "Use the statement name")
        time.sleep(3)
        after = app.ax("dump")[1]
        if again != "The Zoo":
            raise Failed(f"Rename opens with {again!r}, not the place's name")
        if "The Zoo" not in page or "On the statement: Denver Zoo" not in page:
            raise Failed("Rename did not name the place")
        if "The Zoo" in after or "On the statement" in after:
            raise Failed("the statement name did not come back")
        print("PASS Rename names the place, and the statement name comes back")
    finally:
        app.quit()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--binary", default=str(BINARY))
    a = p.parse_args()
    user = json.loads((Path.home() / ".centmemo/test-users.json").read_text())["owner"]
    tool = build_tool()
    SHOTS.mkdir(parents=True, exist_ok=True)
    with devlease.hold(["mac"], task="centmemo mac taps", wait=120):
        item = {"APP_START_TAB": "unexamined", "APP_START_ITEM": UNEXAMINED}
        place = {"APP_START_TAB": "story", "APP_START_ITEM": ZOO}
        bad = 0
        for test, doors in ((memo_round_trip, item), (skip_round_trip, item), (rename_round_trip, place)):
            try:
                test(lambda d=doors: App(tool, a.binary, user, d))
            except Failed as e:
                bad += 1
                print("BLIND" if "BLIND" in str(e) else "FAIL", test.__name__, e)
        return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
