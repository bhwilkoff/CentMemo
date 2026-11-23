"""Is a captured frame blind: one flat color, nothing drawn.

A frame OCR reads as zero words is not unreadable to OCR, so the OCR check passed
two pure black Duo frames on 2026-11-14. XCUITest screenshots the primary display;
an open iPhone Duo has that display off.
"""
import os
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    # Homebrew's python3 comes first on PATH and has no Pillow; the system one
    # does. Re-run the calling tool under it rather than failing mid-tick.
    if sys.executable != "/usr/bin/python3" and os.path.exists("/usr/bin/python3"):
        os.execv("/usr/bin/python3", ["/usr/bin/python3", *sys.argv])
    raise

TOLERANCE = 6      # per channel, from the dominant color
SHARE = 0.99       # fraction of pixels within TOLERANCE that makes a frame blind
CAUSE = "display off / Duo open / device locked"


def is_blind(png):
    im = Image.open(png).convert("RGB")
    im.thumbnail((128, 128))
    px = list(im.getdata())
    base = max(set(px), key=px.count)
    near = sum(1 for p in px if all(abs(p[i] - base[i]) <= TOLERANCE for i in range(3)))
    return near / len(px) >= SHARE


if __name__ == "__main__":
    for f in sys.argv[1:]:
        print(("BLIND " if is_blind(Path(f)) else "ok    ") + f)
