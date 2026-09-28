import Foundation
import Synchronization

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
    /// - Throws: An error if the process cannot be launched, or `CancellationError` if the task is
    ///   cancelled, in which case the process is terminated.
    static func run(
        _ executable: URL,
        arguments: [String],
        environment: [String: String] = [:]
    ) async throws -> ProcessOutput {
        try await run(executable, arguments: arguments, environment: environment, readOutput: readToEnd)
    }

    /// Runs a process with standard input from `/dev/null`, passing each line of its standard
    /// output to a handler as it is written.
    ///
    /// - Parameters:
    ///   - executable: The program to run.
    ///   - arguments: Its arguments.
    ///   - environment: Variables to add to the current environment.
    ///   - onLine: Called with each line of standard output, without its terminator.
    /// - Returns: The exit status and everything written to standard error; `standardOutput` is empty.
    /// - Throws: An error if the process cannot be launched, or `CancellationError` if the task is
    ///   cancelled, in which case the process is terminated.
    static func run(
        _ executable: URL,
        arguments: [String],
        environment: [String: String] = [:],
        onLine: @escaping @Sendable (String) -> Void
    ) async throws -> ProcessOutput {
        try await run(executable, arguments: arguments, environment: environment) { handle in
            var pending = Data()
            for await chunk in chunks(of: handle) {
                pending.append(chunk)
                while let newline = pending.firstIndex(of: UInt8(ascii: "\n")) {
                    onLine(String(decoding: pending[..<newline], as: UTF8.self))
                    pending.removeSubrange(...newline)
                }
            }
            if !pending.isEmpty {
                onLine(String(decoding: pending, as: UTF8.self))
            }
            return Data()
        }
    }

    private static func run(
        _ executable: URL,
        arguments: [String],
        environment: [String: String],
        readOutput: @escaping @Sendable (FileHandle) async -> Data
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
        async let outputData = readOutput(output.fileHandleForReading)
        async let errorData = readToEnd(errors.fileHandleForReading)
        let launch = Mutex(Launch.pending)
        let status: Int32
        do {
            status = try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    launch.withLock { state in
                        guard state == .pending else {
                            continuation.resume(throwing: CancellationError())
                            return
                        }
                        process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
                        do {
                            try process.run()
                            state = .running
                        } catch {
                            process.terminationHandler = nil
                            continuation.resume(throwing: error)
                        }
                    }
                }
            } onCancel: {
                launch.withLock { state in
                    if state == .running {
                        process.terminate()
                    }
                    state = .cancelled
                }
            }
        } catch {
            // Unblock the readers, which would otherwise wait for a writer that never started.
            try? output.fileHandleForWriting.close()
            try? errors.fileHandleForWriting.close()
            _ = await (outputData, errorData)
            throw error
        }
        let result = await ProcessOutput(status: status, standardOutput: outputData, standardError: errorData)
        try Task.checkCancellation()
        return result
    }

    /// Whether a process has been launched, so cancellation knows whether to terminate it.
    private enum Launch {
        case pending
        case running
        case cancelled
    }

    private static func readToEnd(_ handle: FileHandle) async -> Data {
        var result = Data()
        for await chunk in chunks(of: handle) {
            result.append(chunk)
        }
        return result
    }

    /// The data read from a pipe, as it arrives, until end of file.
    ///
    /// Reads happen only when the pipe has data, so no thread waits on a quiet process.
    private static func chunks(of handle: FileHandle) -> AsyncStream<Data> {
        AsyncStream { continuation in
            handle.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    continuation.finish()
                } else {
                    continuation.yield(data)
                }
            }
        }
    }
}
