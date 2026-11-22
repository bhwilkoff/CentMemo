#!/bin/sh
# App Review screen recording (store-submission-playbook, "the screen recording").
# devicectl's screen-record is not supported on the bench iPhone 12, so this
# follows the playbook's method: screenshots in a loop (about 1 per second)
# while ReviewTourUITests walks CentMemo at a human pace, then they are joined,
# each frame held for as long as it was on screen, into a 1080p 30 fps video.
#   tools/record_review.sh   -> build/store-video/centmemo-tour-<date>.mp4
# AVFoundation joins the frames (tools/frames_to_video.swift; Homebrew's ffmpeg was
# broken here). Then: tools/asc_review_attachment.py --platform IOS --file <that file>
set -eu
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
DEVICE=$(python3 -c "import sys; sys.path.insert(0,'tools'); import app_config as c; print(c.DEVICES['iphone'])")
STAMP=$(date +%Y%m%d-%H%M)
FRAMES="build/store-video/frames-$STAMP"; OUT="build/store-video/centmemo-tour-$STAMP.mp4"
mkdir -p "$FRAMES"; STOP="$FRAMES/.stop"
python3 tools/ios_uitest.py --device iphone --only TabSmokeUITests/testUnexamined >/dev/null   # install + warm
# Two capture loops: one devicectl screenshot takes about 3.5 s over USB.
capture() { while [ ! -f "$STOP" ]; do
    f="$FRAMES/$(python3 -c 'import time;print(f"{time.time():.3f}")').png"
    xcrun devicectl device capture screenshot --device "$DEVICE" --destination "$f" --quiet >/dev/null 2>&1 || true
  done; }
capture & L1=$!
sleep 1.7; capture & L2=$!

sleep 2
if ! TEST_RUNNER_REVIEW_TOUR=1 python3 tools/ios_uitest.py --device iphone --only ReviewTourUITests; then
  touch "$STOP"; wait $L1 $L2; echo "tour failed; no video made"; exit 1
fi
sleep 2; touch "$STOP"; wait $L1 $L2
# Keep only the tour itself, between its "launch" and "end" marks: the bench
# phone's home screen (its other apps, its notifications) is not for App Review.
LOG=$(ls -t build/qa/ios-uitest-*/xcodebuild-*.log | head -1)
python3 - "$FRAMES" "$LOG" <<'PY'
import os, re, sys
frames, log = sys.argv[1], sys.argv[2]
marks = dict((m[1], float(m[0])) for m in re.findall(r"TOUR-MARK ([0-9.]+) (launch|end)", open(log, errors="ignore").read()))
if "launch" not in marks or "end" not in marks: sys.exit("no tour marks in " + log)
lo, hi = marks["launch"] + 1.0, marks["end"]
dropped = 0
for f in os.listdir(frames):
    if f.endswith(".png") and not (lo <= float(f[:-4]) <= hi): os.remove(os.path.join(frames, f)); dropped += 1
print(f"kept the tour ({hi - lo:.0f} s); dropped {dropped} frames outside it")
PY
# Blank frames (a locked or black screen) never reach the video.
python3 tools/frame_blind.py "$FRAMES"/*.png | awk '/^BLIND/ {print $2}' | xargs rm -f
swift tools/frames_to_video.swift "$FRAMES" "$OUT"
