import Testing
@testable import Argus

@Suite struct HostLoadTests {
    @Test func utilisationIsLoadPerCore() {
        let load = HostLoad(load: 6, processorCount: 4)
        #expect(load.utilisation == 1.5)
        #expect(load.isOverloaded)
        #expect(!HostLoad(load: 4, processorCount: 4).isOverloaded)
    }

    @Test func busiestKeepsTheMostLoadedInOrder() {
        let loads = [
            HostLoad(load: 1, processorCount: 4),
            HostLoad(load: 3, processorCount: 2),
            HostLoad(load: 0.5, processorCount: 8),
            HostLoad(load: 4, processorCount: 4),
        ]
        #expect(HostLoad.busiest(loads, limit: 2) == [loads[1], loads[3]])
        #expect(HostLoad.busiest(loads, limit: 8) == loads)
    }
}

@MainActor
@Suite struct DockIconTests {
    @Test func monitorReportsLoadOnceCoresAndSamplesAreKnown() async {
        let store = MonitorStore { _ in FakeHost(lines: ["6.00 1.00 1.00"]) }
        store.monitor([RemoteHost(id: .init(), hostname: "nas", port: 22, username: "pi", authentication: .password)])
        let monitor = store.monitors[0]
        #expect(monitor.currentLoad == nil)
        await monitor.settled()
        #expect(monitor.currentLoad == HostLoad(load: 6, processorCount: 4))
    }

    @Test func loadViewBuilds() {
        _ = DockLoadView(loads: [HostLoad(load: 1, processorCount: 4), HostLoad(load: 9, processorCount: 4)]).body
    }
}
