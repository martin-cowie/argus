import Foundation

/// The result of running a process to completion.
struct ProcessOutput: Sendable {
    let status: Int32
    let standardOutput: Data
    let standardError: Data
}

/// Runs external processes without blocking the caller's executor.
enum ProcessRunner {
    /// Runs a process with standard input from `/dev/null`, collecting its output.
    ///
    /// - Parameters:
    ///   - executable: The program to run.
    ///   - arguments: Its arguments.
    ///   - environment: Variables to add to the current environment.
    /// - Returns: The exit status and everything written to standard output and standard error.
    /// - Throws: An error if the process cannot be launched.
    static func run(
        _ executable: URL,
        arguments: [String],
        environment: [String: String] = [:]
    ) async throws -> ProcessOutput {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, added in added }
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = errors

        // Both pipes are drained concurrently so a child filling one cannot deadlock on the other.
        async let outputData = readToEnd(output.fileHandleForReading)
        async let errorData = readToEnd(errors.fileHandleForReading)
        let status: Int32
        do {
            status = try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
                do {
                    try process.run()
                } catch {
                    process.terminationHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        } catch {
            // Unblock the readers, which would otherwise wait for a writer that never started.
            try? output.fileHandleForWriting.close()
            try? errors.fileHandleForWriting.close()
            _ = await (outputData, errorData)
            throw error
        }
        return await ProcessOutput(status: status, standardOutput: outputData, standardError: errorData)
    }

    private static func readToEnd(_ handle: FileHandle) async -> Data {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                continuation.resume(returning: handle.readDataToEndOfFile())
            }
        }
    }
}
