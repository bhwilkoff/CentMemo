#!/usr/bin/env python3
"""The Mac's tap tier, through the real buttons, data left as found: a memo saved, read
back after a relaunch and removed; a purchase skipped and brought back; a place renamed
and given its statement name back; a theme put on a memo; one theme read; the Narrative
filtered; a link made, listed and turned off; a place confirmed; exports
imported; the last lists kept, sealed, shown first and offline; every section of Settings in sight.

Signs in as the synthetic owner through the DEBUG door, never as a person. Presses
controls by accessibility and by process id, so nothing comes to the front. Needs the
terminal's existing Accessibility permission; without it the run is BLIND, not a FAIL.

    /usr/bin/python3 tools/mac_uitest.py [--binary PATH]
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
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


def as_user(user):
    """Calls the server as the person would, to change or clean what a test needs."""
    from urllib.request import Request, urlopen
    js = (REPO / "js/api.js").read_text()
    base, key = re.search(r"https://[a-z0-9]+\.supabase\.co", js).group(0), re.search(r"sb_publishable_[\w-]+|eyJ[\w.-]{60,}", js).group(0)

    def call(path, body=None, method="POST", token=None):
        h = {"apikey": key, "content-type": "application/json", **({"Authorization": f"Bearer {token}"} if token else {})}
        data = None if body is None else json.dumps(body).encode()
        raw = urlopen(Request(base + path, data, h, method=method), timeout=20).read()
        return json.loads(raw) if raw else None
    token = call("/auth/v1/token?grant_type=password", {"email": user["email"], "password": user["password"]})["access_token"]
    return lambda path, body=None, method="POST": call(path, body, method, token)


def skip_on_server(user, on):
    when = datetime.now(timezone.utc).isoformat() if on else None
    as_user(user)(f"/rest/v1/transactions?id=eq.{UNEXAMINED}", {"skipped_at": when}, "PATCH")


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

    def shows(self, text, seconds=40, gone=False):
        for _ in range(seconds):
            if (text in self.ax("dump")[1]) != gone:
                return
            time.sleep(1)
        raise Failed(f"{text!r} {'still there' if gone else 'not shown'} after {seconds}s")

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


def theme_on_memo(open_app):
    chip = "Great meals"
    app = open_app()
    try:
        app.wait("memo-editor", lambda v: v != "")
        on = lambda: "AXSelected 1" in app.ax("state", chip)[1]  # noqa: E731
        if on():
            raise Failed(f"the fixture already has {chip}")
        for want in (True, False):
            app.do("press", chip)
            app.do("press", "save-memo")
            app.wait("memo-status", lambda v: "Saved." in v)
            time.sleep(2)
            app.quit()
            app = open_app()
            app.wait("memo-editor", lambda v: v != "")
            if on() != want:
                raise Failed(f"{chip} {'did not stay' if want else 'did not come off'}")
        print("PASS a theme goes on a memo, and comes off, across relaunches")
    finally:
        app.quit()


def read_one_theme(open_app):
    app = open_app()
    try:
        app.shows("penguins")
        app.do("press", "theme-Great meals")
        app.shows("penguins", gone=True)
        app.shows("Anniversary")
        for i in ("share-theme", "link-theme"):
            app.wait(i)
        app.do("press", "every-memo")
        app.shows("penguins")
        print("PASS one theme is read alone, and Every memo leads back")
    finally:
        app.quit()


def filter_narrative(open_app):
    app = open_app()
    try:
        app.shows("· Shell")
        app.do("press", "narrative-filter")
        time.sleep(1)
        app.do("press", "Written")
        app.shows("· Shell", gone=True)
        app.shows("penguins")
        print("PASS the Narrative shows only what is written")
    finally:
        app.quit()


def link_made_and_off(open_app, open_settings):
    app = open_app()
    try:
        app.wait("link-make")
        app.shows("penguins")
        app.do("press", "share-word-13")
        app.do("press", "share-word-16")
        app.do("press", "Circle")
        app.do("press", "link-make")
        app.wait("link-send")
        app.shows("centmemo.com/s/#")
        print("PASS a link is made, with its address shown")
    finally:
        app.quit()
    app = open_settings()
    try:
        app.shows("link-off-")
        offs = app.do("ids", "link-off-").split()
        for i in offs:
            app.do("press", i)
            time.sleep(3)
        app.shows("link-off-", gone=True)
        print(f"PASS Settings lists it and turns it off ({len(offs)})")
    finally:
        app.quit()


def failing_network(*opens):
    shutil.rmtree(CACHES / "reads", ignore_errors=True)  # nothing kept: the whole screen says so
    for open_app, words in zip(opens, ("CentMemo couldn't reach its server.", "You're offline.")):
        app = open_app()
        try:
            app.shows(words)
            app.do("press", "Try again")
            app.shows(words)
            if "NSURL" in app.ax("dump")[1]:
                raise Failed("the system's own words on screen")
        finally:
            app.quit()
    print("PASS unreachable and offline each say so, with Try again")


def empty_account(open_app):
    app = open_app()
    try:
        app.shows("Nothing in your Narrative yet")
        app.shows("Import")
        macapp.capture(app.pid, str(SHOTS / "empty.png"))
        print("PASS an empty account says so and offers Import")
    finally:
        app.quit()


def theme_added_and_removed(open_app):
    app, name, added = open_app(), "Remove People I love", False
    try:
        app.shows("Starter themes")
        if name in app.ax("dump")[1]:
            raise Failed("the fixture already has People I love")
        app.do("press", app.do("ids", "add-starter-").split()[0])
        added = True
        app.shows(name)
        app.do("press", name)
        app.wait("Keep it")
        app.do("press", "Keep it")
        time.sleep(2)
        app.shows(name)
        print("PASS a starter theme is added; removing asks first, and Keep it keeps it")
    finally:
        if added:
            app.do("press", name)
            app.wait("Remove from all memos")
            app.do("press", "Remove from all memos")
            app.shows(name, gone=True)
            print("PASS and Remove from all memos removes it")
        app.quit()


def reload_lists(open_app, change):
    """A memo-less purchase skipped somewhere else leaves the Mac's list on Reload."""
    app = open_app()
    try:
        app.shows("King Soopers, Nov 17 · ")
        change(True)
        try:
            time.sleep(3)
            if "King Soopers, Nov 17 · " not in app.ax("dump")[1]:
                raise Failed("the list changed before Reload: this proves nothing")
            app.do("press", "menu:Reload")
            app.shows("King Soopers, Nov 17 · ", gone=True)
        finally:
            change(False)
        app.do("press", "menu:Reload")
        app.shows("King Soopers, Nov 17 · ")
        print("PASS View > Reload shows what changed elsewhere")
    finally:
        app.quit()


def import_twice(*opens):
    clean = lambda: subprocess.run(["node", str(REPO / "tools/cleanup_stranger.mjs")], check=True, capture_output=True)  # noqa: E731
    clean()
    try:
        _import_twice(*opens)
    finally:
        clean()


def _import_twice(*opens):
    for open_app, words in zip(opens, ("Apple Card: 3 new.", "Apple Card: 0 new, 3 already in CentMemo.", "Venmo: 3 new.")):
        app = open_app()
        try:
            got = app.wait("import-result", lambda v: v != "")
            if got != words:
                raise Failed(f"import said {got!r}, not {words!r}")
        finally:
            app.quit()
    print("PASS an Apple Card export adds 3, again adds none; a Venmo export adds its own 3")


def place_confirmed(open_app, forget):
    app = open_app()
    try:
        app.wait("every-visit")
        app.do("press", "every-visit")
        app.wait("setting-summary")
        app.wait("place-confirm")
        app.do("press", "place-confirm")
        app.shows("Opens in Maps")
        app.shows("Is this the place?", gone=True)
        print("PASS a place guessed from the statement is confirmed")
    finally:
        app.quit()
        forget()


def sign_out_leaves_nothing(open_app):
    app = open_app()
    try:
        app.shows("Remove Great meals")
        app.do("press", "Account")
        app.wait("Delete account")
        app.do("press", "Sign out")
        app.shows("Sign in with Apple")
        app.shows("Sign in to see your settings.")
        tree = app.ax("dump")[1]
        for left in ("Great meals", "Delete account", "Sign out", "Copy connector"):
            if left in tree:
                raise Failed(f"{left!r} is still on screen after signing out")
        print("PASS signing out leaves nothing of the person, in either window")
    finally:
        app.quit()


def server_ends_the_session(open_app, end):
    """APP_EXPIRE_SESSION makes every call refresh, so the server's refusal is met at once."""
    app = open_app()
    try:
        app.shows("Remove Great meals")
        end()
        app.do("press", "menu:Reload")
        app.shows("Sign in with Apple")
        app.shows("Sign in to see your settings.")
        if "Great meals" in app.ax("dump")[1]:
            raise Failed("the person's themes are still on screen")
        print("PASS a session the server ends leaves nothing of the person either")
    finally:
        app.quit()


CACHES = Path.home() / "Library/Containers/com.learningischange.centmemo/Data/Library/Caches"


def kept_on_this_mac(seen, slow, offline, desk):
    """Opening shows what this Mac last held, before and without the network."""
    for open_app, words in ((seen, "penguins"), (desk[0], "every-visit")):
        app = open_app()
        app.shows(words)
        time.sleep(4)
        app.quit()
    files = list((CACHES / "reads").iterdir())
    raw = b"".join(f.read_bytes() for f in files)
    for word in (b"penguins", b"Denver Zoo", b"txn_date", b"access_token"):
        if word in raw:
            raise Failed(f"{word!r} can be read in the stored files")
    if not files or any((CACHES / "com.learningischange.centmemo" / n).exists() for n in ("Cache.db", "fsCachedData")):
        raise Failed("nothing stored, or the cleartext cache is back")
    print(f"PASS {len(files)} answers stored, none readable, no cleartext cache")
    app = slow()
    try:
        app.shows("penguins", seconds=20)
        print("PASS the Narrative stands while the network has not answered")
    finally:
        app.quit()
    app = offline()
    try:
        app.shows("You're offline.")
        app.shows("penguins", seconds=3)
        app.do("press", "Try again")
        app.shows("penguins", seconds=3)
        print("PASS offline shows the last lists, says so, and offers Try again")
    finally:
        app.quit()
    app = desk[1]()
    try:
        app.wait("memo-editor", seconds=25)
        app.do("type", "memo-editor", "words typed before the answer")
        time.sleep(45)
        if app.do("get", "memo-editor") != "words typed before the answer":
            raise Failed("the late answer replaced the person's words")
        print("PASS a late answer never replaces words being written")
    finally:
        app.quit()


def settings_sections(open_app):
    app = open_app()
    try:
        app.shows("Connect Claude")
        tree = app.ax("dump")[1]
        if "more toolbar items" in tree or "Privacy and terms" not in tree:
            raise Failed("a section of Settings is hidden behind an arrow")
        print("PASS every section of Settings is in sight")
    finally:
        app.quit()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--binary", default=str(BINARY))
    p.add_argument("--only", help="part of a test's name")
    a = p.parse_args()
    users = json.loads((Path.home() / ".centmemo/test-users.json").read_text())
    user = users["owner"]
    tool = build_tool()
    SHOTS.mkdir(parents=True, exist_ok=True)
    with devlease.hold(["mac"], task="centmemo mac taps", wait=120):
        go = lambda **d: lambda: App(tool, a.binary, user, d)  # noqa: E731
        item = go(APP_START_TAB="unexamined", APP_START_ITEM=UNEXAMINED)
        zoo = go(APP_START_TAB="story", APP_START_ITEM=ZOO)
        link = go(APP_START_TAB="story", APP_START_ITEM=ZOO, APP_START_SHARE="link")
        settings = go(APP_START_TAB="story", APP_OPEN_SETTINGS="1", APP_START_PANE="links")
        tests = [(memo_round_trip, item), (skip_round_trip, item), (rename_round_trip, zoo), (theme_on_memo, zoo),
                 (read_one_theme, go(APP_START_TAB="story")), (filter_narrative, go(APP_START_TAB="ledger")),
                 (link_made_and_off, link, settings), (settings_sections, settings),
                 (theme_added_and_removed, go(APP_START_TAB="story", APP_OPEN_SETTINGS="1", APP_START_PANE="themes")),
                 (sign_out_leaves_nothing, go(APP_START_TAB="story", APP_OPEN_SETTINGS="1", APP_START_PANE="themes")),
                 (kept_on_this_mac, go(APP_START_TAB="ledger"), go(APP_START_TAB="ledger", APP_SLOW_MS="40000"),
                  go(APP_START_TAB="ledger", APP_FAIL_NETWORK="offline"), (item, go(APP_START_TAB="unexamined", APP_START_ITEM=UNEXAMINED, APP_SLOW_MS="40000"))),
                 (server_ends_the_session, go(APP_START_TAB="story", APP_OPEN_SETTINGS="1", APP_START_PANE="themes", APP_EXPIRE_SESSION="1"),
                  lambda: as_user(user)("/auth/v1/logout?scope=global", {})),
                 (reload_lists, go(APP_START_TAB="unexamined"), lambda on: skip_on_server(user, on)),
                 (import_twice, *(lambda k=k: App(tool, a.binary, users["stranger"], {
                     "APP_START_TAB": "story", "APP_OPEN_SETTINGS": "1", "APP_START_PANE": "moneyIn", "APP_IMPORT_SAMPLE": k}) for k in ("1", "1", "venmo"))),
                 (place_confirmed, zoo, lambda: as_user(user)("/rest/v1/setting_places?setting=eq.Denver%20Zoo", method="DELETE")),
                 (failing_network, go(APP_START_TAB="ledger", APP_FAIL_NETWORK="unreachable"),
                  go(APP_START_TAB="ledger", APP_FAIL_NETWORK="offline")),
                 (empty_account, lambda: App(tool, a.binary, users["stranger"], {"APP_START_TAB": "unexamined"}))]
        bad = 0
        for test, *opens in tests:
            if a.only and a.only not in test.__name__:
                continue
            try:
                test(*opens)
            except Failed as e:
                bad += 1
                print("BLIND" if "BLIND" in str(e) else "FAIL", test.__name__, e)
        return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
