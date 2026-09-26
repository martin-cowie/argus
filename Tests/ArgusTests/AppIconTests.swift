import Testing
@testable import Argus

@MainActor
@Test(arguments: [16, 64, 1024])
func appIconRendersAtRequestedSize(pixels: Int) throws {
    let image = try #require(AppIcon.cgImage(pixels: pixels))
    #expect(image.width == pixels)
    #expect(image.height == pixels)
}
