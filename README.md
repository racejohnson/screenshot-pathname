# Screenshot Pathname

A macOS menu bar app that copies the full path of every new screenshot to the clipboard, ready to paste into Claude Code, Codex or a terminal.

Take a screenshot, wait a moment for the menu bar icon to flash a checkmark, paste the path.

## Install

```sh
scripts/install.sh
```

Builds the app, replaces `/Applications/Screenshot Pathname.app` and relaunches it. Requires macOS 14 or later and Xcode (for `actool`).

## Build and test

```sh
swift build                # debug build
swift test                 # unit tests and a live FSEvents test
scripts/build-app.sh       # "build/Screenshot Pathname.app", ad-hoc signed
scripts/icon-preview.sh    # render Resources/AppIcon.icon into build/icon-preview/
```

## Which folder it watches

By default it follows the macOS screenshot location, the one set in Cmd-Shift-5 › Options (`defaults read com.apple.screencapture location`), and falls back to `~/Desktop` when none is set, as macOS does. A change there is picked up within a few seconds. Point CleanShot X at the same folder and both tools are covered.

**Folder › Choose Folder…** watches a folder of your own instead; **Use macOS Screenshot Location** switches back. A folder that disappears (an unplugged drive) shows as unavailable and is watched again when it returns.

## What counts as a new screenshot

A png, jpg, jpeg, heic, heif, tiff, tif or gif file created directly in the folder within the last 30 seconds. Hidden temp files, subfolders, screen recordings and old files moved into the folder are ignored.

## Defaults

| Setting | Default |
| --- | --- |
| Copy New Screenshot Paths | On |
| Notify on Copy | Off (asks for notification permission when turned on) |
| Open at Login | Off |
| Folder | macOS screenshot location |

## Troubleshooting

**Notifications show a blank or old icon after the app icon changes.** macOS keeps a stale copy in its system icon cache. Clear it, then restart Notification Center:

```sh
sudo rm -rf /Library/Caches/com.apple.iconservices.store
killall NotificationCenter
```
