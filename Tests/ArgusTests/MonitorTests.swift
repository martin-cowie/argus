import Foundation
import Testing
@testable import Argus

@Suite struct OperatingSystemTests {
    @Test func parsesNameAndVersion() {
        let system = OperatingSystem(scriptOutput: "Ubuntu\n24.04.1 LTS (Noble Numbat)\n")
        #expect(system == OperatingSystem(name: "Ubuntu", version: "24.04.1 LTS (Noble Numbat)"))
    }

    @Test(arguments: ["", "\n", "\nDebian\n", "Linux"])
    func rejectsOutputWithoutNameAndVersion(output: String) {
        #expect(OperatingSystem(scriptOutput: output) == nil)
    }

    @Test func scriptDescribesThisMac() async throws {
        let output = try await ProcessRunner.run(URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", OperatingSystem.script])
        let system = try #require(OperatingSystem(scriptOutput: String(decoding: output.standardOutput, as: UTF8.self)))
        let version = ProcessInfo.processInfo.operatingSystemVersion
        #expect(system.name == "macOS")
        #expect(system.version.hasPrefix("\(version.majorVersion).\(version.minorVersion)"))
    }
}

@MainActor
@Suite struct MonitorStoreTests {
    private nonisolated static let linux = OperatingSystem(name: "Debian GNU/Linux", version: "12 (bookworm)")

    private func host(_ name: String) -> RemoteHost {
        RemoteHost(id: UUID(), hostname: name, port: 22, username: "pi", authentication: .password)
    }

    @Test func reportsOperatingSystem() async {
        let store = MonitorStore { _ in Self.linux }
        store.monitor([host("nas")])
        let monitor = store.monitors[0]
        await monitor.settled()
        #expect(monitor.status == .connected(Self.linux))
    }

    @Test func reportsFailure() async {
        let store = MonitorStore { _ in throw SSHError.connectionFailed("Connection refused") }
        store.monitor([host("nas")])
        let monitor = store.monitors[0]
        await monitor.settled()
        #expect(monitor.status == .failed("Connection refused"))
    }

    @Test func monitorsEachHostOnceInOrder() {
        let store = MonitorStore { _ in Self.linux }
        let nas = host("nas")
        let router = host("router")
        store.monitor([nas])
        store.monitor([router, nas])
        #expect(store.monitors.map(\.id) == [nas.id, router.id])
    }

    @Test func stopRemovesMonitorAndCancelsConnection() async {
        let store = MonitorStore { _ in
            try await Task.sleep(for: .seconds(30))
            return Self.linux
        }
        let nas = host("nas")
        store.monitor([nas])
        let monitor = store.monitors[0]
        store.stop(nas.id)
        await monitor.settled()
        #expect(store.monitors.isEmpty)
        #expect(monitor.status == .connecting)
    }
}
