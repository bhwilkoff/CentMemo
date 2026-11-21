#!/bin/sh
# Render every brand asset from branding/brand.html (headless Chrome). Re-run
# after any change to the mark; never hand-export. Output: the iOS icon (light
# and dark), web icons, the Open Graph image, and wordmarks.
set -e
cd "$(dirname "$0")/.."
C="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
SRC="file://$PWD/branding/brand.html"
shot() { "$C" --headless=new --hide-scrollbars --force-device-scale-factor=1 --window-size="$2" \
  --virtual-time-budget=8000 --screenshot="$3" "$SRC?$1" 2>/dev/null; }
I=apple/Assets.xcassets/AppIcon.appiconset
shot "kind=icon&concept=a&size=1024" 1024,1024 "$I/icon-1024.png"
shot "kind=icon&concept=a&size=1024&dark=1" 1024,1024 "$I/icon-1024-dark.png"
cp "$I/icon-1024-dark.png" assets/brand/icon-1024-dark.png 2>/dev/null || true
mkdir -p assets/brand
shot "kind=icon&concept=a&size=1024" 1024,1024 assets/brand/icon-1024.png
shot "kind=og&concept=a" 1200,630 assets/og.png
shot "kind=wordmark&concept=a&size=2000" 2000,500 assets/brand/wordmark.png
shot "kind=wordmark&concept=a&size=2000&dark=1" 2000,500 assets/brand/wordmark-dark.png
# Smaller sizes are downsampled from the 1024 master (sips keeps it crisp).
for s in 180 192 512 32; do sips -z $s $s assets/brand/icon-1024.png --out assets/brand/icon-$s.png >/dev/null; done
cp assets/brand/icon-180.png assets/apple-touch-icon.png
cp assets/brand/icon-32.png assets/favicon-32.png
echo "rendered brand assets"
