import Foundation

/// A Unix host that Argus connects to over SSH.
struct RemoteHost: Identifiable, Codable, Hashable, Sendable {
    /// How Argus authenticates with a host.
    enum Authentication: Codable, Hashable, Sendable {
        /// A private key file. Passphrase-protected keys must be loaded into `ssh-agent`.
        case key(path: String)
        /// A password, held in the Keychain under the host's `id`.
        case password
    }

    /// The standard SSH port.
    static let defaultPort = 22

    let id: UUID
    let hostname: String
    let port: Int
    let username: String
    let authentication: Authentication

    /// The host as `user@hostname`, with the port appended when it is not the default.
    var displayName: String {
        let address = port == Self.defaultPort ? hostname : "\(hostname):\(port)"
        return "\(username)@\(address)"
    }
}

/// Validation rules for the parts of a host's address.
enum HostAddress {
    /// The range of valid TCP port numbers.
    static let validPorts = 1...65535

    /// Whether a string is an IPv4 address, an IPv6 address or an RFC 1123 hostname.
    ///
    /// - Parameter address: The candidate hostname or IP address, without surrounding whitespace.
    /// - Returns: `true` if the address is well formed.
    static func isValid(_ address: String) -> Bool {
        isIPAddress(address) || isHostname(address)
    }

    private static func isIPAddress(_ address: String) -> Bool {
        var ipv4 = in_addr()
        var ipv6 = in6_addr()
        return inet_pton(AF_INET, address, &ipv4) == 1 || inet_pton(AF_INET6, address, &ipv6) == 1
    }

    private static func isHostname(_ address: String) -> Bool {
        let name = address.hasSuffix(".") ? String(address.dropLast()) : address
        guard !name.isEmpty, name.utf8.count <= 253 else { return false }
        let labels = name.split(separator: ".", omittingEmptySubsequences: false)
        // An all-numeric top-level label is disallowed (RFC 3696 §2), so a mistyped IPv4
        // address such as 256.1.1.1 is not mistaken for a hostname.
        let hasNumericTopLevel = labels.count > 1 && labels.last?.allSatisfy(\.isNumber) == true
        return !hasNumericTopLevel && labels.allSatisfy(isLabel)
    }

    private static func isLabel(_ label: Substring) -> Bool {
        (1...63).contains(label.utf8.count)
            && label.first != "-"
            && label.last != "-"
            && label.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
    }
}
