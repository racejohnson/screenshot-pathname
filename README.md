# ScreenshotPathname

Menu bar app for macOS 13+ that watches a screenshots folder and copies the newest screenshot path to the clipboard.

## Features

- Menu bar only app (`LSUIElement`)
- Toggle `Enable Auto Copy Path` (persisted)
- Watches folder for new image files (`.png`, `.jpg`, `.jpeg`, `.heic`)
- Debounced event handling to avoid duplicate fires
- Copies full POSIX path to clipboard
- Optional local notification (`AppConfig.shouldNotifyOnCopy`)
- `Open Screenshots Folder` menu action
- `Start at Login` toggle using `SMAppService.mainApp`
- Missing-folder fallback with `Choose Folder…` and security-scoped bookmark persistence

## Run Without Xcode (recommended for your setup)

From `/Users/racejohnson/Codex/screenshot-pathname`:

```bash
./scripts/build_app.sh
./scripts/run_app.sh
```

This builds `build/ScreenshotPathname.app` using `swiftc` from Command Line Tools and launches it.

## Optional: Install to Applications

```bash
pkill -x ScreenshotPathname || true
rm -rf /Applications/ScreenshotPathname.app
cp -R "/Users/racejohnson/Codex/screenshot-pathname/build/ScreenshotPathname.app" /Applications/
open /Applications/ScreenshotPathname.app
```

For `Start at Login`, running from `/Applications` is more reliable.

## Build With Xcode (if installed later)

1. Open `/Users/racejohnson/Codex/screenshot-pathname/ScreenshotPathname.xcodeproj` in Xcode 15+.
2. In target settings, set your signing team and bundle identifier if needed.
3. Build and run the `ScreenshotPathname` scheme.

Optional CLI build from full Xcode:

```bash
xcodebuild -project "/Users/racejohnson/Codex/screenshot-pathname/ScreenshotPathname.xcodeproj" -scheme ScreenshotPathname -configuration Debug build
```

## Entitlements

- Default project is unsandboxed and does not require additional entitlements.
- Local notifications only require runtime user permission.
- If you later sandbox the app, add:
  - `com.apple.security.app-sandbox = true`
  - `com.apple.security.files.user-selected.read-only = true`

## Defaults

- Default folder: `/Users/racejohnson/Screenshots`
- Debounce interval: `0.5` seconds
- Auto-copy default: enabled
- Start at login default: disabled
- Copy notification default: enabled

## Notification Prompt Troubleshooting

- macOS shows the notification permission prompt only once per app bundle identifier.
- If you do not see the prompt again, reset it and relaunch:

```bash
tccutil reset Notifications com.racejohnson.ScreenshotPathname
```
