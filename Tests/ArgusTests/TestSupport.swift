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
