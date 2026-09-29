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
@Suite struct LoadChartTests {
    private func samples(_ loads: Double...) -> [LoadSample] {
        loads.map { LoadSample(date: .now, load: LoadAverage(oneMinute: $0, fiveMinutes: 0.5, fifteenMinutes: 0.25)) }
    }

    @Test func builds() {
        _ = LoadChart(samples: samples(1), processorCount: 4).body
    }

    @Test func marksCoreCountOnlyWhenLoadExceedsIt() {
        #expect(LoadChart(samples: samples(1, 4), processorCount: 4).overloadedProcessorCount == nil)
        #expect(LoadChart(samples: samples(1, 4.01, 2), processorCount: 4).overloadedProcessorCount == 4)
        #expect(LoadChart(samples: samples(9), processorCount: nil).overloadedProcessorCount == nil)
    }
}

@MainActor
@Test func addHostViewBuilds() {
    _ = AddHostView(existingHosts: []) { _, _ in }.body
}

@MainActor
@Test func aboutCreditsLinkToNamesake() {
    let credits = AboutPanel.credits
    #expect(credits.string == "Argus of the thousand eyes")
    #expect(credits.attribute(.link, at: 0, effectiveRange: nil) as? URL == AboutPanel.namesakeURL)
}
