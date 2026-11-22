#!/usr/bin/env python3
"""A read-only look around Apple Wallet on Ben's Duo (his request, 2026-11-22).

Runs WalletTourUITests (opens the Apple Card and a few purchases, never anything
that moves money) and, while Wallet is in front, photographs the Duo's inner
display (XCUITest's own frames come from the dark outer display). Everything
lands in build/qa/wallet-tour-<date>/: frames, plus each screen's accessibility
labels as text. Local only (build/ is gitignored): it is Ben's own Wallet.

    python3 tools/wallet_tour.py
"""
import os, subprocess, sys, threading, time
from datetime import date
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import app_config, apple_device as ad, frame_blind
from ios_uitest import displays

UDID = "00008160-001814623AA00036"
OUT = app_config.REPO / "build" / "qa" / f"wallet-tour-{date.today().isoformat()}"


def sampler(stop, ids):
    n = 0
    while not stop.is_set():
        if ad.app_alive(UDID, executable="Passbook") is True:
            for i, did in enumerate(ids):
                p = OUT / f"frame-{n:03d}-display{i}.png"
                ad.devicectl("device", "capture", "screenshot", "--device", UDID, "--display-unique-id", did, "--destination", str(p))
                if ad.app_alive(UDID, executable="Passbook") is not True:
                    p.unlink(missing_ok=True)  # Wallet left the screen mid-capture: not ours to keep
                elif p.exists() and frame_blind.is_blind(p):
                    p.unlink()
            n += 1
        stop.wait(4)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    stop = threading.Event()
    t = threading.Thread(target=sampler, args=(stop, displays(UDID)), daemon=True)
    t.start()
    env = {**os.environ, "CENTMEMO_UITEST_DUO": "1", "TEST_RUNNER_WALLET_TOUR": "1"}
    r = subprocess.run([sys.executable, "tools/ios_uitest.py", "--device", "duo", "--only", "WalletTourUITests"],
                       cwd=app_config.REPO, env=env, capture_output=True, text=True)
    stop.set(); t.join(timeout=30)
    print("\n".join(l for l in r.stdout.splitlines() if l.startswith(("PASS", "FAIL", "SKIP", "BLIND", "  frames"))))
    print(f"frames: {len(list(OUT.glob('frame-*.png')))} in {OUT}")
    return r.returncode


if __name__ == "__main__":
    sys.exit(main())
