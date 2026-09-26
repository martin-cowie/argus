import AppKit

/// Writes the app icon as a macOS `.iconset` directory, ready for `iconutil -c icns`.
///
/// Compiled together with `Sources/Argus/AppIcon.swift` by `scripts/bundle.sh`.
/// Usage: `export-icon <output.iconset>`
@main
@MainActor
enum ExportIcon {
    private static let pointSizes = [16, 32, 128, 256, 512]

    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            FileHandle.standardError.write(Data("usage: export-icon <output.iconset>\n".utf8))
            exit(64)
        }
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for points in pointSizes {
            try writePNG(pixels: points, to: directory.appendingPathComponent("icon_\(points)x\(points).png"))
            try writePNG(pixels: points * 2, to: directory.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
        }
    }

    private static func writePNG(pixels: Int, to url: URL) throws {
        guard let image = AppIcon.cgImage(pixels: pixels),
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: url.path])
        }
        try png.write(to: url)
    }
}
