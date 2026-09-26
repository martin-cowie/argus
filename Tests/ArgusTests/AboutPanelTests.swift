import AppKit
import Testing
@testable import Argus

@MainActor
@Suite struct AboutPanelTests {
    @Test func legendNamesArgusPanoptes() {
        #expect(AboutPanel.legend.contains("Argus Panoptes"))
    }

    @Test func creditsCarryTheLegend() throws {
        let credits = try #require(AboutPanel.options(infoDictionary: nil)[.credits] as? NSAttributedString)
        #expect(credits.string == AboutPanel.legend)
    }

    @Test func versionComesFromInfoPlist() {
        let options = AboutPanel.options(infoDictionary: ["CFBundleShortVersionString": "0.1.0"])
        #expect(options[.applicationVersion] as? String == "0.1.0")
    }

    @Test func versionIsOmittedWithoutInfoPlist() {
        #expect(AboutPanel.options(infoDictionary: nil)[.applicationVersion] == nil)
    }
}
