import Foundation
import Observation
import os

/// The user's hosts, persisted as JSON in Application Support, with passwords in a `PasswordStore`.
@MainActor
@Observable
final class HostStore {
    private static let logger = Logger(subsystem: "com.example.argus", category: "HostStore")

    /// The hosts, in the order they were added.
    private(set) var hosts: [RemoteHost]

    private let fileURL: URL
    private let passwords: any PasswordStore

    /// The default location of the hosts file.
    static var defaultFileURL: URL {
        URL.applicationSupportDirectory.appending(components: "Argus", "hosts.json")
    }

    /// Loads the hosts from disk.
    ///
    /// An unreadable hosts file is moved aside to `<name>.unreadable` rather than overwritten,
    /// and the store starts empty.
    ///
    /// - Parameters:
    ///   - fileURL: The JSON file holding the hosts.
    ///   - passwords: Where host passwords are kept.
    init(fileURL: URL = HostStore.defaultFileURL, passwords: any PasswordStore = KeychainPasswordStore()) {
        self.fileURL = fileURL
        self.passwords = passwords
        self.hosts = Self.load(from: fileURL)
    }

    /// Adds a host and saves it.
    ///
    /// - Parameters:
    ///   - host: The host to add.
    ///   - password: The host's password, for password authentication.
    /// - Throws: An error if the password or the hosts file cannot be written.
    func add(_ host: RemoteHost, password: String?) throws {
        if let password {
            try passwords.setPassword(password, for: host.id)
        }
        try save(hosts + [host])
    }

    /// Removes a host and its stored password.
    ///
    /// - Parameter host: The host to remove.
    /// - Throws: An error if the password or the hosts file cannot be updated.
    func remove(_ host: RemoteHost) throws {
        try save(hosts.filter { $0.id != host.id })
        try passwords.deletePassword(for: host.id)
    }

    /// Retrieves a host's stored password.
    ///
    /// - Parameter host: The host.
    /// - Returns: The password, or `nil` if none is stored.
    /// - Throws: An error if the password store cannot be read.
    func password(for host: RemoteHost) throws -> String? {
        try passwords.password(for: host.id)
    }

    private func save(_ newHosts: [RemoteHost]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(newHosts).write(to: fileURL, options: .atomic)
        hosts = newHosts
    }

    private static func load(from url: URL) -> [RemoteHost] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            return try JSONDecoder().decode([RemoteHost].self, from: Data(contentsOf: url))
        } catch {
            let aside = url.appendingPathExtension("unreadable")
            logger.error("Cannot read \(url.path, privacy: .public), moving it to \(aside.path, privacy: .public): \(error)")
            try? FileManager.default.removeItem(at: aside)
            try? FileManager.default.moveItem(at: url, to: aside)
            return []
        }
    }
}
