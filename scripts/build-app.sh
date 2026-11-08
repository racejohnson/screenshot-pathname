#!/bin/zsh
# Builds build/ScreenshotPathname.app: release binary, Info.plist, compiled icon assets, ad-hoc signature.
set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/build/ScreenshotPathname.app"
CONTENTS="$APP/Contents"

echo "Building release binary…"
swift build -c release --package-path "$ROOT"
BIN_DIR="$(swift build -c release --package-path "$ROOT" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN_DIR/ScreenshotPathname" "$CONTENTS/MacOS/ScreenshotPathname"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"

assets=()
for source in "$ROOT/Resources/AppIcon.icon" "$ROOT/Resources/Assets.xcassets"; do
  [[ -e "$source" ]] && assets+=("$source")
done

if (( ${#assets} )); then
  echo "Compiling assets…"
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  xcrun actool "${assets[@]}" \
    --compile "$CONTENTS/Resources" \
    --platform macosx \
    --minimum-deployment-target 14.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "$TMP/partial.plist" \
    --output-format human-readable-text
else
  echo "No icon assets yet; skipping actool."
fi

plutil -lint "$CONTENTS/Info.plist"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"

echo "$APP"
