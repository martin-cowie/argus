import Charts
import SwiftUI

/// An area chart of the one-minute load average, with the latest averages above it.
struct LoadChart: View {
    /// The samples to plot, oldest first; there must be at least one.
    let samples: [LoadSample]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            latest
            Chart(samples, id: \.date) { sample in
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

    private var latest: some View {
        let load = samples[samples.count - 1].load
        return Text("Load average \(format(load.oneMinute)), \(format(load.fiveMinutes)), \(format(load.fifteenMinutes))")
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
}
