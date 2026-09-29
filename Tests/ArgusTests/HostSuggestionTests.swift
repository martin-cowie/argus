import Foundation
import Testing
@testable import Argus

@Suite struct KnownHostsTests {
    @Test func readsFirstNameOfEachLineOnce() {
        let contents = """
            nas.local,192.168.1.10 ssh-ed25519 AAAA
            nas.local,192.168.1.10 ecdsa-sha2-nistp256 AAAA
            [router]:2222 ssh-ed25519 AAAA
            10.0.0.5 ssh-rsa AAAA
            """
        #expect(KnownHosts.hosts(in: contents) == [
            HostSuggestion(hostname: "nas.local", port: 22),
            HostSuggestion(hostname: "router", port: 2222),
            HostSuggestion(hostname: "10.0.0.5", port: 22),
        ])
    }

    @Test func skipsLinesThatNameNoSingleHost() {
        let contents = """
            # a comment

            |1|F1E1KeoE/eEWhi10WpGv4OdiO6Y=|3988QV0VE8wmZL7suNrYQLITLCg= ssh-rsa AAAA
            @cert-authority *.example.com ssh-rsa AAAA
            @revoked nas ssh-rsa AAAA
            *.example.com ssh-rsa AAAA
            server? ssh-rsa AAAA
            !bad ssh-rsa AAAA
            [router]:99999 ssh-rsa AAAA
            """
        #expect(KnownHosts.hosts(in: contents).isEmpty)
    }

    @Test func missingFileHasNoHosts() async {
        #expect(await KnownHosts.load(from: temporaryHostsFile()).isEmpty)
    }
}

@Suite struct HostSuggestionTests {
    private let bonjour = [HostSuggestion(hostname: "nas.local", port: 2222)]
    private let known = [
        HostSuggestion(hostname: "NAS.local", port: 22),
        HostSuggestion(hostname: "router", port: 22),
        HostSuggestion(hostname: "backup", port: 22),
    ]

    @Test func keepsSourcesApartAndEarlierSourceWins() {
        let merged = HostSuggestion.merge([bonjour, known], excluding: [], matching: "")
        #expect(merged == [
            [HostSuggestion(hostname: "nas.local", port: 2222)],
            [HostSuggestion(hostname: "backup", port: 22), HostSuggestion(hostname: "router", port: 22)],
        ])
    }

    @Test func leavesOutExistingHostsAndNonMatches() {
        let merged = HostSuggestion.merge([bonjour, known], excluding: ["Router"], matching: " A ")
        #expect(merged.map { $0.map(\.hostname) } == [["nas.local"], ["backup"]])
    }
}

@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["CI"] == nil, "CI runners may have no multicast DNS"))
struct BonjourBrowserTests {
    @Test func findsAdvertisedServer() async throws {
        let name = "Argus Test \(UUID().uuidString.prefix(8))"
        let advertiser = Process()
        advertiser.executableURL = URL(fileURLWithPath: "/usr/bin/dns-sd")
        advertiser.arguments = ["-R", name, "_ssh._tcp", "local", "2299"]
        advertiser.standardOutput = FileHandle.nullDevice
        try advertiser.run()
        defer { advertiser.terminate() }

        let browser = BonjourBrowser()
        let browsing = Task { await browser.browse() }
        defer { browsing.cancel() }
        let deadline = ContinuousClock.now + .seconds(10)
        while !browser.hosts.contains(where: { $0.port == 2299 }), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        let host = try #require(browser.hosts.first { $0.port == 2299 })
        #expect(host.hostname.hasSuffix(".local"))
    }
}
