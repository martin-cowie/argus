import Foundation
import SwiftUI
import Testing
@testable import Argus

@MainActor
@Test func contentViewBuilds() {
    let store = HostStore(fileURL: temporaryHostsFile(), passwords: InMemoryPasswordStore())
    let monitors = MonitorStore { _ in FakeHost() }
    _ = ContentView(hosts: store, monitors: monitors).body
}

@MainActor
@Test func loadChartBuilds() {
    let sample = LoadSample(date: .now, load: LoadAverage(oneMinute: 1, fiveMinutes: 0.5, fifteenMinutes: 0.25))
    _ = LoadChart(samples: [sample]).body
}

@MainActor
@Test func aboutCreditsLinkToNamesake() {
    let credits = AboutPanel.credits
    #expect(credits.string == "Argus of the thousand eyes")
    #expect(credits.attribute(.link, at: 0, effectiveRange: nil) as? URL == AboutPanel.namesakeURL)
}
