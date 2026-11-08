#!/bin/zsh
# Builds the app, replaces "/Applications/Screenshot Pathname.app" and relaunches it.
set -euo pipefail

ROOT="${0:A:h:h}"
BUNDLE_ID="com.racejohnson.ScreenshotPathname"
NAME="Screenshot Pathname.app"
TARGET="/Applications/$NAME"
LEGACY="/Applications/ScreenshotPathname.app"   # the name before 2.0

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
# Copy first, then swap, so a failed copy leaves the old app in place. The copy keeps its
# .app name throughout: a bundle that appears under any other name is remembered as a folder.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$ROOT/build/$NAME" "$STAGE/$NAME"
rm -rf "$TARGET" "$LEGACY"
mv "$STAGE/$NAME" "$TARGET"
open "$TARGET"
echo "Installed and launched $TARGET"
