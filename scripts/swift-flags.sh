#!/bin/sh
# Prints extra `swift build` flags needed when building with the Command Line Tools.
#
# The Command Line Tools ship the Swift Testing macro plugin in a directory the compiler does not
# search by default, and do not ship the SwiftUI macro plugin (needed for `@State`) at all, so it
# is borrowed from Xcode when installed. Neither is needed when Xcode is the selected toolchain.
set -eu

clt_testing=/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
xcode_plugins=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins

case "$(xcode-select -p)" in
*CommandLineTools*)
    for dir in "$clt_testing" "$xcode_plugins"; do
        if [ -d "$dir" ]; then
            printf -- '-Xswiftc -plugin-path -Xswiftc %s ' "$dir"
        fi
    done
    ;;
esac
