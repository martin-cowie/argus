import Foundation
import SwiftUI
import Testing
@testable import Argus

@MainActor
@Test func contentViewBuilds() {
    let store = HostStore(fileURL: temporaryHostsFile(), passwords: InMemoryPasswordStore())
    _ = ContentView(store: store).body
}

@MainActor
@Test func aboutCreditsLinkToNamesake() {
    let credits = AboutPanel.credits
    #expect(credits.string == "Argus of the thousand eyes")
    #expect(credits.attribute(.link, at: 0, effectiveRange: nil) as? URL == AboutPanel.namesakeURL)
}
