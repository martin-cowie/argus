import Foundation

/// Running a command over SSH failed.
enum SSHError: LocalizedError, Equatable {
    /// `ssh` could not connect or authenticate.
    case connectionFailed(String)
    /// The remote command exited unsuccessfully.
    case commandFailed(status: Int32, message: String)
    /// Password authentication was chosen but no password is stored.
    case missingPassword
    /// The remote command's output was not in the expected form.
    case unexpectedOutput

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let message): message.isEmpty ? "Couldn't connect." : message
        case .commandFailed(let status, let message): message.isEmpty ? "The command failed with status \(status)." : message
        case .missingPassword: "No password is stored for this host."
        case .unexpectedOutput: "The host's reply wasn't understood."
        }
    }
}

/// Runs shell scripts on a host.
protocol ScriptRunner: Sendable {
    /// Runs a script to completion.
    ///
    /// - Parameter script: A POSIX shell script.
    /// - Returns: The script's standard output.
    /// - Throws: An error if the script cannot be run or fails.
    func run(_ script: String) async throws -> String

    /// Runs a long-lived script, delivering its output as it is printed.
    ///
    /// - Parameter script: A POSIX shell script.
    /// - Returns: The lines of the script's standard output, finishing when it exits and throwing
    ///   if it cannot be run or fails.
    func lines(_ script: String) -> AsyncThrowingStream<String, any Error>
}

/// Runs shell scripts on a remote host with the system's OpenSSH client.
struct SSHClient: ScriptRunner {
    /// The status `ssh` exits with when it cannot connect or authenticate.
    private static let sshFailureStatus: Int32 = 255
    private static let ssh = URL(fileURLWithPath: "/usr/bin/ssh")

    let host: RemoteHost
    /// The host's password, required for password authentication.
    let password: String?

    /// Runs a POSIX shell script on the host.
    ///
    /// - Parameter script: The script, run by the remote `sh`.
    /// - Returns: The script's standard output, decoded as UTF-8.
    /// - Throws: `SSHError` if the connection or the script fails, or `CancellationError` if the
    ///   task is cancelled.
    func run(_ script: String) async throws -> String {
        let output = try await ProcessRunner.run(
            Self.ssh,
            arguments: arguments(remoteCommand: Self.remoteCommand(for: script)),
            environment: try environment()
        )
        try Self.checkStatus(of: output)
        return String(decoding: output.standardOutput, as: UTF8.self)
    }

    /// Runs a long-lived POSIX shell script on the host, delivering its output as it is printed.
    ///
    /// Ending iteration early, or cancelling the iterating task, disconnects.
    ///
    /// - Parameter script: The script, run by the remote `sh`.
    /// - Returns: The lines of the script's standard output. The stream finishes when the script
    ///   exits, throwing `SSHError` if the connection or the script fails.
    func lines(_ script: String) -> AsyncThrowingStream<String, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let output = try await ProcessRunner.run(
                        Self.ssh,
                        arguments: arguments(remoteCommand: Self.remoteCommand(for: script)),
                        environment: try environment()
                    ) { continuation.yield($0) }
                    try Self.checkStatus(of: output)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func checkStatus(of output: ProcessOutput) throws {
        let message = String(decoding: output.standardError, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        switch output.status {
        case 0: return
        case sshFailureStatus: throw SSHError.connectionFailed(message)
        default: throw SSHError.commandFailed(status: output.status, message: message)
        }
    }

    /// The `ssh` arguments for running a command on the host.
    ///
    /// New host keys are accepted and remembered on first use; changed keys are refused.
    ///
    /// - Parameter remoteCommand: The command line for the remote shell.
    /// - Returns: The arguments, ending with the destination and command.
    func arguments(remoteCommand: String) -> [String] {
        let common = [
            "-p", String(host.port),
            "-l", host.username,
            "-o", "ConnectTimeout=10",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "LogLevel=ERROR",
        ]
        let authentication = switch host.authentication {
        case .key(let path):
            ["-i", path, "-o", "IdentitiesOnly=yes", "-o", "BatchMode=yes", "-o", "PreferredAuthentications=publickey"]
        case .password:
            ["-o", "PreferredAuthentications=password,keyboard-interactive", "-o", "PubkeyAuthentication=no", "-o", "NumberOfPasswordPrompts=1"]
        }
        return common + authentication + ["--", host.hostname, remoteCommand]
    }

    /// Wraps a script so it survives whatever login shell the remote user has.
    ///
    /// - Parameter script: The POSIX shell script.
    /// - Returns: A command line that decodes the script and pipes it to `sh`.
    static func remoteCommand(for script: String) -> String {
        "echo \(Data(script.utf8).base64EncodedString()) | base64 -d | sh"
    }

    private func environment() throws -> [String: String] {
        guard case .password = host.authentication else { return [:] }
        guard let password else { throw SSHError.missingPassword }
        // ssh reads passwords only from a terminal or an askpass program, so it is handed one
        // that echoes the password from the environment rather than from its arguments.
        return [
            "SSH_ASKPASS": try Askpass.helperPath(),
            "SSH_ASKPASS_REQUIRE": "force",
            Askpass.passwordVariable: password,
        ]
    }
}

/// A helper script for `SSH_ASKPASS` that prints the password from the environment.
private enum Askpass {
    static let passwordVariable = "ARGUS_SSH_PASSWORD"

    static func helperPath() throws -> String {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Argus", isDirectory: true)
        let helper = directory.appendingPathComponent("askpass.sh")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try Data("#!/bin/sh\nprintf '%s\\n' \"$\(passwordVariable)\"\n".utf8).write(to: helper, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helper.path)
        return helper.path
    }
}
