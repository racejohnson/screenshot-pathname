#!/bin/zsh
# Builds the app, replaces /Applications/ScreenshotPathname.app and relaunches it.
set -euo pipefail

ROOT="${0:A:h:h}"
BUNDLE_ID="com.racejohnson.ScreenshotPathname"
TARGET="/Applications/ScreenshotPathname.app"

"$ROOT/scripts/build-app.sh"

wait_for_exit() {
  for _ in {1..$1}; do
    pgrep -x ScreenshotPathname >/dev/null || return 0
    sleep 0.1
  done
}

if pgrep -x ScreenshotPathname >/dev/null; then
  echo "Quitting the running app…"
  osascript -e "quit app id \"$BUNDLE_ID\"" >/dev/null 2>&1 || true
  wait_for_exit 50
  pkill -x ScreenshotPathname 2>/dev/null && wait_for_exit 20
  pkill -9 -x ScreenshotPathname 2>/dev/null && wait_for_exit 20
fi

echo "Installing to $TARGET…"
# Copy first, then swap, so a failed copy leaves the old app in place.
rm -rf "$TARGET.new"
ditto "$ROOT/build/ScreenshotPathname.app" "$TARGET.new"
rm -rf "$TARGET"
mv "$TARGET.new" "$TARGET"
open "$TARGET"
echo "Installed and launched $TARGET"
