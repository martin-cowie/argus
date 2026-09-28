import SwiftUI
import Testing
@testable import Argus

@MainActor
@Test func contentViewBuilds() {
    _ = ContentView().body
}

@MainActor
@Test func aboutCreditsLinkToNamesake() {
    let credits = AboutPanel.credits
    #expect(credits.string == "Argus of the thousand eyes")
    #expect(credits.attribute(.link, at: 0, effectiveRange: nil) as? URL == AboutPanel.namesakeURL)
}
