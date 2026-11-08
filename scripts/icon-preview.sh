#!/bin/zsh
# Render Resources/AppIcon.icon in every appearance and at Finder sizes into build/icon-preview/.
# Usage: scripts/icon-preview.sh   (needs Xcode, which ships Icon Composer's ictool)
set -euo pipefail
cd "${0:A:h}/.."
ictool="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
icon=Resources/AppIcon.icon
out=build/icon-preview
rm -rf $out && mkdir -p $out

render() { # rendition size scale file
  "$ictool" $icon --export-image --output-file "$out/$4" --platform macOS \
    --rendition $1 --width $2 --height $2 --scale $3 >/dev/null
}

render Default 1024 1 Default-1024.png
for rendition in Default Dark ClearLight ClearDark TintedLight TintedDark; do
  render $rendition 256 1 $rendition-256.png
done
for size in 16 32 64 128; do
  render Default $size 1 Default-$size.png
  render Default $size 2 Default-$size@2x.png
done

echo "Rendered $(ls $out | wc -l | tr -d ' ') images into $out/"
