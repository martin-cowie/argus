#!/bin/sh
# Builds a release binary and wraps it in dist/Argus.app.
set -eu

cd "$(dirname "$0")/.."

flags=$(scripts/swift-flags.sh)
# shellcheck disable=SC2086 # $flags holds several words
swift build -c release $flags
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
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Resources/AppIcon.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
    sips -z "$((size * 2))" "$((size * 2))" Resources/AppIcon.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
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
    <key>NSLocalNetworkUsageDescription</key><string>Argus looks for SSH servers on your local network.</string>
    <key>NSBonjourServices</key><array><string>_ssh._tcp</string></array>
</dict>
</plist>
PLIST

codesign --force --sign - "$app"
echo "Built $app"
