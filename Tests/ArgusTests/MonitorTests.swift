import Foundation
import Testing
@testable import Argus

@Suite struct SystemInfoTests {
    @Test func parsesOperatingSystemAndCores() {
        let system = SystemInfo(scriptOutput: "Ubuntu\n24.04.1 LTS (Noble Numbat)\n8\n")
        #expect(system?.operatingSystem == OperatingSystem(name: "Ubuntu", version: "24.04.1 LTS (Noble Numbat)"))
        #expect(system?.processorCount == 8)
    }

    @Test(arguments: ["Linux\n6.1\n\n", "Linux\n6.1\n0\n", "Linux\n6.1"])
    func toleratesMissingCoreCount(output: String) throws {
        let system = try #require(SystemInfo(scriptOutput: output))
        #expect(system.processorCount == nil)
    }

    @Test(arguments: ["", "\n", "\nDebian\n", "Linux"])
    func rejectsOutputWithoutNameAndVersion(output: String) {
        #expect(SystemInfo(scriptOutput: output) == nil)
    }

    @Test func scriptDescribesThisMac() async throws {
        let output = try await ProcessRunner.run(URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", SystemInfo.script])
        let system = try #require(SystemInfo(scriptOutput: String(decoding: output.standardOutput, as: UTF8.self)))
        let version = ProcessInfo.processInfo.operatingSystemVersion
        #expect(system.operatingSystem.name == "macOS")
        #expect(system.operatingSystem.version.hasPrefix("\(version.majorVersion).\(version.minorVersion)"))
        #expect(system.processorCount == ProcessInfo.processInfo.activeProcessorCount)
    }
}

@Suite struct LoadAverageTests {
    @Test(arguments: ["0.52 0.58 0.59", " 1.95 2.10 2.27 "])
    func parsesThreeAverages(line: String) throws {
        let load = try #require(LoadAverage(line: line))
        #expect(load.oneMinute > 0.5 && load.fiveMinutes > 0.5 && load.fifteenMinutes > 0.5)
    }

    @Test(arguments: ["", "0.52 0.58", "0.52 0.58 0.59 1/123", "0,52 0,58 0,59"])
    func rejectsOtherLines(line: String) {
        #expect(LoadAverage(line: line) == nil)
    }

    @Test func scriptSamplesThisMac() async throws {
        let (lines, continuation) = AsyncStream.makeStream(of: String.self)
        let task = Task {
            try await ProcessRunner.run(URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", LoadAverage.script]) {
                continuation.yield($0)
            }
        }
        var iterator = lines.makeAsyncIterator()
        let line = await iterator.next()
        task.cancel()
        #expect(LoadAverage(line: try #require(line)) != nil)
    }
}

@MainActor
@Suite struct MonitorStoreTests {
    private func host(_ name: String) -> RemoteHost {
        RemoteHost(id: UUID(), hostname: name, port: 22, username: "pi", authentication: .password)
    }

    @Test func reportsOperatingSystemAndLoad() async {
        let store = MonitorStore { _ in FakeHost(lines: ["0.50 0.40 0.30", "1.00 0.50 0.25"]) }
        store.monitor([host("nas")])
        let monitor = store.monitors[0]
        await monitor.settled()
        #expect(monitor.system == SystemInfo(
            operatingSystem: OperatingSystem(name: "Debian GNU/Linux", version: "12 (bookworm)"),
            processorCount: 4
        ))
        #expect(monitor.samples.map(\.load) == [
            LoadAverage(oneMinute: 0.5, fiveMinutes: 0.4, fifteenMinutes: 0.3),
            LoadAverage(oneMinute: 1, fiveMinutes: 0.5, fifteenMinutes: 0.25),
        ])
        #expect(monitor.status == .failed("The connection closed."))
    }

    @Test func reportsConnectionFailure() async {
        let store = MonitorStore { _ in throw SSHError.connectionFailed("Connection refused") }
        store.monitor([host("nas")])
        let monitor = store.monitors[0]
        await monitor.settled()
        #expect(monitor.status == .failed("Connection refused"))
    }

    @Test func reportsUnexpectedLoadOutput() async {
        let store = MonitorStore { _ in FakeHost(lines: ["sysctl: unknown oid"]) }
        store.monitor([host("nas")])
        let monitor = store.monitors[0]
        await monitor.settled()
        #expect(monitor.status == .failed(SSHError.unexpectedOutput.localizedDescription))
    }

    @Test func monitorsEachHostOnceInOrder() {
        let store = MonitorStore { _ in FakeHost(staysConnected: true) }
        let nas = host("nas")
        let router = host("router")
        store.monitor([nas])
        store.monitor([router, nas])
        #expect(store.monitors.map(\.id) == [nas.id, router.id])
        store.stop(nas.id)
        store.stop(router.id)
    }

    @Test func stopRemovesMonitorAndDisconnects() async {
        let store = MonitorStore { _ in FakeHost(lines: ["0.50 0.40 0.30"], staysConnected: true) }
        let nas = host("nas")
        store.monitor([nas])
        let monitor = store.monitors[0]
        while monitor.samples.isEmpty {
            await Task.yield()
        }
        store.stop(nas.id)
        await monitor.settled()
        #expect(store.monitors.isEmpty)
        #expect(monitor.status == .monitoring)
    }
}
