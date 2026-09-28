#!/bin/sh
# Builds a release binary and wraps it in dist/Argus.app.
set -eu

cd "$(dirname "$0")/.."

swift build -c release
bin_dir=$(swift build -c release --show-bin-path)

app=dist/Argus.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/argus" "$app/Contents/MacOS/Argus"
cp -R "$bin_dir/argus_Argus.bundle" "$app/Contents/Resources/"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
iconset="$work/AppIcon.iconset"
mkdir "$iconset"
# Apple's icon grid centres 824px of artwork on a 1024px canvas.
rsvg-convert --width 824 --height 824 --page-width 1024 --page-height 1024 --left 100 --top 100 \
    --output "$work/icon-1024.png" Resources/AppIcon.svg
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$work/icon-1024.png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    sips -z "$((size * 2))" "$((size * 2))" "$work/icon-1024.png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil --convert icns --output "$app/Contents/Resources/AppIcon.icns" "$iconset"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Argus</string>
    <key>CFBundleDisplayName</key><string>Argus</string>
    <key>CFBundleIdentifier</key><string>com.example.argus</string>
    <key>CFBundleExecutable</key><string>Argus</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$app"
echo "Built $app"
