import AppKit
import Observation
import SwiftUI

/// A monitored host's latest one-minute load relative to its core count.
struct HostLoad: Equatable {
    let load: Double
    let processorCount: Int

    /// The load per core; above 1 when work is queuing for the processors.
    var utilisation: Double { load / Double(processorCount) }
    var isOverloaded: Bool { load > Double(processorCount) }

    /// Picks the most heavily loaded hosts, keeping their original order.
    ///
    /// - Parameters:
    ///   - loads: Every host's load, in display order.
    ///   - limit: The most hosts to keep.
    /// - Returns: At most `limit` loads, those with the highest utilisation.
    static func busiest(_ loads: [HostLoad], limit: Int) -> [HostLoad] {
        let kept = Set(loads.indices.sorted { loads[$0].utilisation > loads[$1].utilisation }.prefix(limit))
        return loads.indices.filter(kept.contains).map { loads[$0] }
    }
}

extension HostMonitor {
    /// The latest load relative to the host's cores, once both are known.
    var currentLoad: HostLoad? {
        guard let sample = samples.last, let processorCount = system?.processorCount else { return nil }
        return HostLoad(load: sample.load.oneMinute, processorCount: processorCount)
    }
}

/// Optionally replaces the Dock icon with bars showing each monitored host's load, as Activity
/// Monitor can.
@MainActor
final class DockIcon {
    /// The most hosts shown; more would make the bars too thin to read.
    static let maximumBars = 8

    /// Whether the Dock icon shows load rather than the application icon.
    var showsLoad = false {
        didSet {
            if !isObserving {
                isObserving = true
                observe()
            } else {
                refresh()
            }
        }
    }

    private let monitors: MonitorStore
    private var isObserving = false
    private var imageView: NSImageView?

    /// Creates a controller that does nothing until `showsLoad` is first set.
    ///
    /// - Parameter monitors: The monitors whose load is shown.
    init(monitors: MonitorStore) {
        self.monitors = monitors
    }

    private func observe() {
        withObservationTracking {
            refresh()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observe() }
        }
    }

    private func refresh() {
        let loads = HostLoad.busiest(monitors.monitors.compactMap(\.currentLoad), limit: Self.maximumBars)
        let tile = NSApplication.shared.dockTile
        guard showsLoad, !loads.isEmpty else {
            if tile.contentView != nil {
                tile.contentView = nil
                imageView = nil
                tile.display()
            }
            return
        }
        let renderer = ImageRenderer(content: DockLoadView(loads: loads).frame(width: tile.size.width, height: tile.size.height))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return }
        if imageView == nil {
            let view = NSImageView(frame: NSRect(origin: .zero, size: tile.size))
            view.imageScaling = .scaleProportionallyUpOrDown
            tile.contentView = view
            imageView = view
        }
        imageView?.image = image
        tile.display()
    }
}

/// A Dock tile with one bar per host, full height at one load unit per core and red above it.
struct DockLoadView: View {
    let loads: [HostLoad]

    var body: some View {
        GeometryReader { geometry in
            // Apple's icon grid centres 824 of 1024 points of artwork.
            let side = min(geometry.size.width, geometry.size.height) * 824 / 1024
            let padding = side * 0.14
            RoundedRectangle(cornerRadius: side * 0.225, style: .continuous)
                .fill(Color(white: 0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: side * 0.225, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: max(1, side * 0.01))
                }
                .overlay {
                    HStack(alignment: .bottom, spacing: side * 0.04) {
                        ForEach(loads.indices, id: \.self) { index in
                            bar(loads[index], height: side - 2 * padding)
                        }
                    }
                    .padding(padding)
                }
                .frame(width: side, height: side)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }

    private func bar(_ load: HostLoad, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height * 0.03)
            .fill(load.isOverloaded ? Color.red : Color.green)
            .frame(maxWidth: .infinity)
            .frame(height: max(height * 0.03, height * min(load.utilisation, 1)))
    }
}
