import Foundation
import Testing
@testable import Argus

@Suite struct ProcessRunnerTests {
    @Test func collectsLargeOutputFromBothStreams() async throws {
        let output = try await ProcessRunner.run(
            URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "head -c 1000000 /dev/zero; head -c 200000 /dev/zero >&2; exit 3"]
        )
        #expect(output.status == 3)
        #expect(output.standardOutput.count == 1_000_000)
        #expect(output.standardError.count == 200_000)
    }

    @Test func passesEnvironment() async throws {
        let output = try await ProcessRunner.run(
            URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "printf %s \"$ARGUS_TEST\""],
            environment: ["ARGUS_TEST": "watching"]
        )
        #expect(String(decoding: output.standardOutput, as: UTF8.self) == "watching")
    }

    @Test func throwsWhenExecutableIsMissing() async {
        await #expect(throws: (any Error).self) {
            try await ProcessRunner.run(URL(fileURLWithPath: "/nonexistent"), arguments: [])
        }
    }
}

@Suite struct SSHClientTests {
    @Test func keyAuthenticationUsesOnlyThatKeyWithoutPrompting() {
        let host = RemoteHost(id: UUID(), hostname: "nas", port: 2222, username: "pi", authentication: .key(path: "/keys/id"))
        let arguments = SSHClient(host: host, password: nil).arguments(remoteCommand: "true")
        #expect(arguments.starts(with: ["-p", "2222", "-l", "pi"]))
        #expect(arguments.contains("BatchMode=yes"))
        #expect(arguments.contains("IdentitiesOnly=yes"))
        #expect(arguments.suffix(3) == ["--", "nas", "true"])
    }

    @Test func passwordAuthenticationDisablesKeys() {
        let host = RemoteHost(id: UUID(), hostname: "nas", port: 22, username: "pi", authentication: .password)
        let arguments = SSHClient(host: host, password: "secret").arguments(remoteCommand: "true")
        #expect(arguments.contains("PubkeyAuthentication=no"))
        #expect(!arguments.contains("secret"))
    }

    @Test func missingPasswordFailsBeforeConnecting() async {
        let host = RemoteHost(id: UUID(), hostname: "nas", port: 22, username: "pi", authentication: .password)
        await #expect(throws: SSHError.missingPassword) {
            try await SSHClient(host: host, password: nil).run("true")
        }
    }

    @Test func remoteCommandRoundTripsScript() async throws {
        let script = "printf '%s' \"it's $((6 * 7))\""
        let output = try await ProcessRunner.run(
            URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", SSHClient.remoteCommand(for: script)]
        )
        #expect(String(decoding: output.standardOutput, as: UTF8.self) == "it's 42")
    }
}

@Suite struct SSHConnectionTests {
    @Test func refusedConnectionIsAConnectionFailure() async {
        let host = RemoteHost(id: UUID(), hostname: "127.0.0.1", port: 1, username: "nobody", authentication: .key(path: "/dev/null"))
        await #expect {
            try await SSHClient(host: host, password: nil).run("true")
        } throws: { error in
            guard case SSHError.connectionFailed(let message) = error else { return false }
            return message.contains("refused")
        }
    }
}
