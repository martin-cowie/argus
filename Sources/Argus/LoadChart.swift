import Charts
import SwiftUI

/// An area chart of the one-minute load average, with the latest averages above it.
///
/// When the load exceeds the host's core count, the count is drawn as a red line.
struct LoadChart: View {
    /// The samples to plot, oldest first; there must be at least one.
    let samples: [LoadSample]
    /// The host's number of cores, if known.
    let processorCount: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            latest
            Chart {
                ForEach(samples, id: \.date) { sample in
                    AreaMark(x: .value("Time", sample.date), y: .value("Load", sample.load.oneMinute))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(
                            .linearGradient(
                                colors: [.accentColor.opacity(0.4), .accentColor.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    LineMark(x: .value("Time", sample.date), y: .value("Load", sample.load.oneMinute))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Color.accentColor)
                }
                if let cores = overloadedProcessorCount {
                    RuleMark(y: .value("Cores", cores))
                        .foregroundStyle(.red)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .annotation(position: .top, alignment: .leading) {
                            Text(Self.describeCores(cores))
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                }
            }
            .chartXScale(domain: timeWindow)
            .chartXAxis {
                AxisMarks(values: .stride(by: .minute, count: 2)) {
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
            .frame(height: 160)
        }
    }

    /// The core count, when any plotted load exceeds it.
    var overloadedProcessorCount: Int? {
        guard let processorCount,
              samples.contains(where: { $0.load.oneMinute > Double(processorCount) })
        else { return nil }
        return processorCount
    }

    private var latest: some View {
        let load = samples[samples.count - 1].load
        let averages = "Load average \(format(load.oneMinute)), \(format(load.fiveMinutes)), \(format(load.fifteenMinutes))"
        return Text(processorCount.map { "\(averages) on \(Self.describeCores($0))" } ?? averages)
            .monospacedDigit()
            .help("Over the last 1, 5 and 15 minutes")
    }

    /// The history window ending at the latest sample, so the plot fills from the right.
    private var timeWindow: ClosedRange<Date> {
        let end = samples[samples.count - 1].date
        return end.addingTimeInterval(-TimeInterval(HostMonitor.history.components.seconds))...end
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }

    private static func describeCores(_ count: Int) -> String {
        count == 1 ? "1 core" : "\(count) cores"
    }
}
