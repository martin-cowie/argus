import Foundation

/// The editable state of the Add RemoteHost form.
struct HostDraft {
    /// The authentication method chosen in the form.
    enum Method: Hashable, CaseIterable {
        case key
        case password
    }

    var hostname = ""
    var port = RemoteHost.defaultPort
    var username = NSUserName()
    var method = Method.key
    var keyPath = HostDraft.defaultKeyPath() ?? ""
    var password = ""

    var hostnameIsValid: Bool { HostAddress.isValid(trimmed(hostname)) }
    var portIsValid: Bool { HostAddress.validPorts.contains(port) }

    var usernameIsValid: Bool {
        let name = trimmed(username)
        return !name.isEmpty && !name.contains { $0.isWhitespace || $0 == "@" }
    }

    var credentialIsValid: Bool {
        switch method {
        case .key: FileManager.default.isReadableFile(atPath: expandedKeyPath)
        case .password: !password.isEmpty
        }
    }

    var isValid: Bool { hostnameIsValid && portIsValid && usernameIsValid && credentialIsValid }

    /// Builds a host from the form.
    ///
    /// - Parameter id: The new host's identifier.
    /// - Returns: The host, or `nil` if the form is not valid.
    func makeHost(id: UUID = UUID()) -> RemoteHost? {
        guard isValid else { return nil }
        let authentication: RemoteHost.Authentication = switch method {
        case .key: .key(path: expandedKeyPath)
        case .password: .password
        }
        return RemoteHost(
            id: id,
            hostname: trimmed(hostname),
            port: port,
            username: trimmed(username),
            authentication: authentication
        )
    }

    /// The password to store with the host, if password authentication is chosen.
    var passwordToStore: String? { method == .password ? password : nil }

    private var expandedKeyPath: String { NSString(string: trimmed(keyPath)).expandingTildeInPath }

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The first of the user's conventional SSH private keys that exists, if any.
    static func defaultKeyPath() -> String? {
        let sshDirectory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
        return ["id_ed25519", "id_ecdsa", "id_rsa"]
            .map { sshDirectory.appendingPathComponent($0).path }
            .first { FileManager.default.isReadableFile(atPath: $0) }
    }
}
