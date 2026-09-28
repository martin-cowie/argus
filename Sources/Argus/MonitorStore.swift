import Foundation
import Observation

/// The hosts being monitored, in the order monitoring started.
@MainActor
@Observable
final class MonitorStore {
    /// Connects to a host and reports its operating system.
    typealias Probe = @Sendable (RemoteHost) async throws -> OperatingSystem

    private(set) var monitors: [HostMonitor] = []

    private let probe: Probe

    /// Creates an empty store.
    ///
    /// - Parameter probe: How each monitor connects to its host.
    init(probe: @escaping Probe) {
        self.probe = probe
    }

    /// Starts monitoring hosts, skipping any already monitored.
    ///
    /// - Parameter hosts: The hosts to monitor.
    func monitor(_ hosts: some Sequence<RemoteHost>) {
        let monitored = Set(monitors.map(\.id))
        monitors += hosts
            .filter { !monitored.contains($0.id) }
            .map { HostMonitor(host: $0, probe: probe) }
    }

    /// Stops monitoring a host and abandons any connection in progress.
    ///
    /// - Parameter hostID: The host's identifier. Nothing happens if it is not monitored.
    func stop(_ hostID: RemoteHost.ID) {
        monitors.first { $0.id == hostID }?.cancel()
        monitors.removeAll { $0.id == hostID }
    }
}

/// Monitors one host, connecting to it in the background.
@MainActor
@Observable
final class HostMonitor: Identifiable {
    /// How far monitoring has got.
    enum Status: Equatable {
        case connecting
        case connected(OperatingSystem)
        case failed(String)
    }

    let host: RemoteHost
    private(set) var status = Status.connecting

    @ObservationIgnored private var task: Task<Void, Never>?

    nonisolated var id: RemoteHost.ID { host.id }

    /// Starts connecting to a host.
    ///
    /// - Parameters:
    ///   - host: The host to monitor.
    ///   - probe: How to connect to it.
    init(host: RemoteHost, probe: @escaping MonitorStore.Probe) {
        self.host = host
        task = Task { [weak self] in
            let status: Status
            do {
                status = .connected(try await probe(host))
            } catch is CancellationError {
                return
            } catch {
                status = .failed(error.localizedDescription)
            }
            self?.status = status
        }
    }

    /// Waits until the connection attempt succeeds, fails or is cancelled.
    func settled() async {
        await task?.value
    }

    /// Abandons the connection.
    func cancel() {
        task?.cancel()
    }
}
