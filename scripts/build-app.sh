#!/bin/zsh
# Builds "build/Screenshot Pathname.app".
#   scripts/build-app.sh           universal (arm64 + x86_64) release build
#   scripts/build-app.sh --debug   native-arch debug build
# Signs with the first Developer ID Application or Apple Development identity in the keychain,
# else ad-hoc. Set SIGN_IDENTITY to choose one ("-" forces ad-hoc).
set -euo pipefail

ROOT="${0:A:h:h}"
EXECUTABLE="ScreenshotPathname"
APP="$ROOT/build/Screenshot Pathname.app"

# A real identity gives a designated requirement that survives rebuilds, so macOS keeps the
# login item and notification permission. Ad-hoc builds are identified by hash instead.
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
  IDENTITIES="$(security find-identity -v -p codesigning 2>/dev/null || true)"
  SIGN_IDENTITY="$( { grep -o '"Developer ID Application: [^"]*"' <<<"$IDENTITIES" \
    || grep -o '"Apple Development: [^"]*"' <<<"$IDENTITIES" || true; } | head -1 | tr -d '"')"
  SIGN_IDENTITY="${SIGN_IDENTITY:--}"
fi

case "${1:-}" in
  "")      BUILD_ARGS=(-c release --arch arm64 --arch x86_64) ;;
  --debug) BUILD_ARGS=(-c debug) ;;
  *)       echo "usage: ${0:t} [--debug]" >&2; exit 64 ;;
esac

# SwiftPM records the deployment target as the binary's SDK version, which makes macOS
# run the app in compatibility mode (old-style controls). Record the real SDK instead.
MIN_MACOS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$ROOT/Resources/Info.plist")"
SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
BUILD_ARGS+=(-Xlinker -platform_version -Xlinker macos -Xlinker "$MIN_MACOS" -Xlinker "$SDK_VERSION")

echo "==> Compiling"
swift build --package-path "$ROOT" "${BUILD_ARGS[@]}"
BIN_DIR="$(swift build --package-path "$ROOT" "${BUILD_ARGS[@]}" --show-bin-path)"

echo "==> Assembling bundle"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$EXECUTABLE" "$APP/Contents/MacOS/$EXECUTABLE"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

echo "==> Compiling icons"
xcrun actool "$ROOT/Resources/AppIcon.icon" "$ROOT/Resources/Assets.xcassets" \
  --compile "$APP/Contents/Resources" \
  --app-icon AppIcon \
  --enable-on-demand-resources NO \
  --development-region en \
  --target-device mac \
  --platform macosx \
  --minimum-deployment-target "$MIN_MACOS" \
  --output-partial-info-plist "$TMP/partial.plist" >/dev/null

echo "==> Signing (identity: $SIGN_IDENTITY)"
SIGN_ARGS=(--force --options runtime --sign "$SIGN_IDENTITY")
# Notarization needs a secure timestamp; only Developer ID builds get notarized.
if [[ "$SIGN_IDENTITY" == "Developer ID Application:"* ]]; then SIGN_ARGS+=(--timestamp); fi
codesign "${SIGN_ARGS[@]}" "$APP"
codesign --verify --strict "$APP"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
echo "==> Built $APP (version $VERSION)"
