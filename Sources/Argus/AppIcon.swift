import AppKit
import SwiftUI

/// The Argus app icon: a watchful eye on a dark rounded square.
///
/// Drawn at 1024×1024 points, following the macOS icon grid (an 824-point body with margin
/// for the shadow). The iris uses peacock blues, after the eyes Hera set in the peacock's tail.
struct AppIconView: View {
    /// The side length, in points, of the full icon canvas.
    static let canvasSize: CGFloat = 1024

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.12, green: 0.15, blue: 0.34), Color(red: 0.03, green: 0.04, blue: 0.13)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.35), radius: 12, y: 12)
            eye
                .frame(width: 660, height: 380)
        }
        .frame(width: Self.canvasSize, height: Self.canvasSize)
    }

    private var eye: some View {
        ZStack {
            EyeShape().fill(Color(white: 0.96))
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.25, green: 0.85, blue: 0.75),
                            Color(red: 0.05, green: 0.45, blue: 0.70),
                            Color(red: 0.05, green: 0.15, blue: 0.40),
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: 160
                    )
                )
                .frame(width: 310, height: 310)
            Circle()
                .fill(.black)
                .frame(width: 130, height: 130)
            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: 52, height: 52)
                .offset(x: 52, y: -52)
        }
        .clipShape(EyeShape())
        .overlay(EyeShape().stroke(Color(red: 0.55, green: 0.75, blue: 0.95), lineWidth: 14))
    }
}

/// An almond-shaped eye outline spanning the full width of its frame.
struct EyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var result = Path()
        let left = CGPoint(x: rect.minX, y: rect.midY)
        let right = CGPoint(x: rect.maxX, y: rect.midY)
        // A quadratic curve reaches half-way to its control point, so the controls sit at
        // twice the frame's half-height to make the lids touch the frame's edges.
        result.move(to: left)
        result.addQuadCurve(to: right, control: CGPoint(x: rect.midX, y: rect.midY - rect.height))
        result.addQuadCurve(to: left, control: CGPoint(x: rect.midX, y: rect.midY + rect.height))
        result.closeSubpath()
        return result
    }
}

/// Renders the app icon to bitmaps.
@MainActor
enum AppIcon {
    /// Renders the icon as a square bitmap.
    ///
    /// - Parameter pixels: The width and height of the bitmap, in pixels.
    /// - Returns: The rendered bitmap, or `nil` if rendering failed.
    static func cgImage(pixels: Int) -> CGImage? {
        let renderer = ImageRenderer(content: AppIconView())
        renderer.scale = CGFloat(pixels) / AppIconView.canvasSize
        return renderer.cgImage
    }

    /// Renders the icon for use as `NSApplication.applicationIconImage`.
    ///
    /// - Returns: A 512-point image backed by a 1024-pixel bitmap, or `nil` if rendering failed.
    static func nsImage() -> NSImage? {
        guard let bitmap = cgImage(pixels: 1024) else { return nil }
        return NSImage(cgImage: bitmap, size: NSSize(width: 512, height: 512))
    }
}
