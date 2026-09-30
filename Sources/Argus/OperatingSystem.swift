import Foundation

/// The name and version of a host's operating system.
struct OperatingSystem: Equatable, Sendable {
    let name: String
    let version: String

    /// A POSIX shell script that prints the name and version on separate lines.
    ///
    /// Linux and the BSDs describe themselves in `/etc/os-release`, macOS through `sw_vers`;
    /// anything else falls back to the kernel's name and release.
    static let script = """
        if [ -r /etc/os-release ]; then
            . /etc/os-release
            printf '%s\\n%s\\n' "${NAME:-$(uname -s)}" "${VERSION:-${VERSION_ID:-$(uname -r)}}"
        elif command -v sw_vers >/dev/null 2>&1; then
            sw_vers -productName
            sw_vers -productVersion
        else
            uname -s
            uname -r
        fi
        """
}

extension OperatingSystem {
    /// Parses the output of `script`.
    ///
    /// - Parameter scriptOutput: What the script printed.
    /// - Returns: `nil` if the output does not name an operating system.
    init?(scriptOutput: String) {
        let lines = scriptOutput.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard lines.count >= 2, !lines[0].isEmpty else { return nil }
        name = lines[0]
        version = lines[1]
    }

    /// Asks a host for its operating system.
    ///
    /// - Parameter host: Runs scripts on the host.
    /// - Returns: The host's operating system.
    /// - Throws: An error if the host cannot be reached, `SSHError.unexpectedOutput` if its reply
    ///   is not understood, or `CancellationError` if the task is cancelled.
    static func fetch(from host: some ScriptRunner) async throws -> OperatingSystem {
        guard let result = OperatingSystem(scriptOutput: try await host.run(script)) else {
            throw SSHError.unexpectedOutput
        }
        return result
    }
}
