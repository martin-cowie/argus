import Foundation
import Observation

/// The hosts being monitored, in the order monitoring started.
@MainActor
@Observable
final class MonitorStore {
    /// Opens a connection for running scripts on a host.
    typealias Connect = @Sendable (RemoteHost) async throws -> any ScriptRunner

    private(set) var monitors: [HostMonitor] = []

    private let connect: Connect

    /// Creates an empty store.
    ///
    /// - Parameter connect: How each monitor connects to its host.
    init(connect: @escaping Connect) {
        self.connect = connect
    }

    /// Starts monitoring hosts, skipping any already monitored.
    ///
    /// - Parameter hosts: The hosts to monitor.
    func monitor(_ hosts: some Sequence<RemoteHost>) {
        let monitored = Set(monitors.map(\.id))
        monitors += hosts
            .filter { !monitored.contains($0.id) }
            .map { HostMonitor(host: $0, connect: connect) }
    }

    /// Stops monitoring a host and disconnects from it.
    ///
    /// - Parameter hostID: The host's identifier. Nothing happens if it is not monitored.
    func stop(_ hostID: RemoteHost.ID) {
        monitors.first { $0.id == hostID }?.cancel()
        monitors.removeAll { $0.id == hostID }
    }
}

/// A load average and when it was received.
struct LoadSample: Equatable, Sendable {
    let date: Date
    let load: LoadAverage
}

/// Monitors one host in the background: identifies its operating system, then samples its load.
@MainActor
@Observable
final class HostMonitor: Identifiable {
    /// How far monitoring has got.
    enum Status: Equatable {
        case connecting
        case monitoring
        case failed(String)
    }

    /// How much load history is kept.
    static let history = Duration.seconds(10 * 60)

    let host: RemoteHost
    private(set) var status = Status.connecting
    private(set) var operatingSystem: OperatingSystem?
    /// The load samples received within `history`, oldest first.
    private(set) var samples: [LoadSample] = []

    @ObservationIgnored private var task: Task<Void, Never>?

    nonisolated var id: RemoteHost.ID { host.id }

    /// Starts connecting to a host.
    ///
    /// - Parameters:
    ///   - host: The host to monitor.
    ///   - connect: How to connect to it.
    init(host: RemoteHost, connect: @escaping MonitorStore.Connect) {
        self.host = host
        task = Task { [weak self] in
            do {
                let runner = try await connect(host)
                let system = try await OperatingSystem.fetch(from: runner)
                self?.operatingSystem = system
                self?.status = .monitoring
                for try await line in runner.lines(LoadAverage.script) {
                    guard let load = LoadAverage(line: line) else { throw SSHError.unexpectedOutput }
                    guard let self else { return }
                    self.record(load)
                }
                if !Task.isCancelled {
                    self?.status = .failed("The connection closed.")
                }
            } catch is CancellationError {
                return
            } catch {
                self?.status = .failed(error.localizedDescription)
            }
        }
    }

    /// Waits until monitoring fails or is cancelled.
    func settled() async {
        await task?.value
    }

    /// Disconnects from the host.
    func cancel() {
        task?.cancel()
    }

    private func record(_ load: LoadAverage) {
        let now = Date.now
        let cutoff = now.addingTimeInterval(-TimeInterval(Self.history.components.seconds))
        samples.removeAll { $0.date < cutoff }
        samples.append(LoadSample(date: now, load: load))
    }
}
