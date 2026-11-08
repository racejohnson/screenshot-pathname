#!/bin/zsh
# Builds the release app, installs it as "/Applications/Screenshot Pathname.app"
# (replacing any older copy), and opens it.
set -euo pipefail

ROOT="${0:A:h:h}"
APP_NAME="Screenshot Pathname"
BUILT="$ROOT/build/$APP_NAME.app"
INSTALLED="/Applications/$APP_NAME.app"
LEGACY="/Applications/ScreenshotPathname.app"   # the name before 2.0

"$ROOT/scripts/build-app.sh"

if pgrep -x ScreenshotPathname >/dev/null; then
  osascript -e 'quit app id "com.racejohnson.ScreenshotPathname"' >/dev/null 2>&1 || true
  for _ in {1..50}; do pgrep -x ScreenshotPathname >/dev/null || break; sleep 0.1; done
  pkill -x ScreenshotPathname && sleep 0.5 || true
fi

echo "==> Installing"
rm -rf "$INSTALLED" "$LEGACY"
# Move rather than copy, so Spotlight and Launch Services only ever see one copy, and only
# ever under its .app name (a bundle first seen under another name is remembered as a folder).
mv "$BUILT" "$INSTALLED"

open "$INSTALLED"
echo "==> Installed and opened $INSTALLED"
