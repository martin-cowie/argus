import Foundation

/// A host's load averages over the last one, five and fifteen minutes.
struct LoadAverage: Equatable, Sendable {
    let oneMinute: Double
    let fiveMinutes: Double
    let fifteenMinutes: Double

    /// How often `script` prints a sample.
    static let interval = Duration.seconds(5)

    /// A POSIX shell script that prints the three load averages on a line, repeatedly.
    ///
    /// Linux exposes them in `/proc/loadavg`; macOS and the BSDs through `sysctl`.
    static let script = """
        # ssh forwards the local locale, which could otherwise print decimal commas.
        LC_ALL=C
        export LC_ALL
        while :; do
            if [ -r /proc/loadavg ]; then
                cut -d ' ' -f 1-3 /proc/loadavg
            else
                sysctl -n vm.loadavg | tr -d '{}'
            fi || exit
            sleep \(interval.components.seconds)
        done
        """
}

extension LoadAverage {
    /// Parses a line printed by `script`.
    ///
    /// - Parameter line: Three decimal numbers separated by whitespace.
    /// - Returns: `nil` if the line is not in that form.
    init?(line: String) {
        let fields = line.split(whereSeparator: \.isWhitespace)
        let values = fields.compactMap { Double($0) }
        guard fields.count == 3, values.count == 3 else { return nil }
        oneMinute = values[0]
        fiveMinutes = values[1]
        fifteenMinutes = values[2]
    }
}
