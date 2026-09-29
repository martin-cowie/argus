import Foundation
import Synchronization
@testable import Argus

/// A `PasswordStore` that keeps passwords in memory.
final class InMemoryPasswordStore: PasswordStore {
    private let passwords = Mutex<[UUID: String]>([:])

    func setPassword(_ password: String, for hostID: UUID) throws {
        passwords.withLock { $0[hostID] = password }
    }

    func password(for hostID: UUID) throws -> String? {
        passwords.withLock { $0[hostID] }
    }

    func deletePassword(for hostID: UUID) throws {
        passwords.withLock { $0[hostID] = nil }
    }
}

/// A path for a hosts file in a fresh temporary directory.
func temporaryHostsFile() -> URL {
    FileManager.default.temporaryDirectory
        .appending(components: "ArgusTests-\(UUID().uuidString)", "hosts.json")
}

/// A host that answers scripts with canned output.
struct FakeHost: ScriptRunner {
    /// What `run` prints, as `SystemInfo.script` would.
    var output = "Debian GNU/Linux\n12 (bookworm)\n4\n"
    /// The lines `lines` prints.
    var lines: [String] = []
    /// Whether the `lines` stream stays open after the last line, as a live connection would.
    var staysConnected = false

    func run(_ script: String) async throws -> String {
        output
    }

    func lines(_ script: String) -> AsyncThrowingStream<String, any Error> {
        AsyncThrowingStream { continuation in
            for line in lines {
                continuation.yield(line)
            }
            if !staysConnected {
                continuation.finish()
            }
        }
    }
}
