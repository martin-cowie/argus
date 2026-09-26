import Foundation
import Security

/// Secure storage for host passwords, keyed by host identifier.
protocol PasswordStore: Sendable {
    /// Stores or replaces the password for a host.
    ///
    /// - Throws: `KeychainError` if the password cannot be stored.
    func setPassword(_ password: String, for hostID: UUID) throws

    /// Retrieves the password for a host.
    ///
    /// - Returns: The password, or `nil` if none is stored.
    /// - Throws: `KeychainError` if the store cannot be read.
    func password(for hostID: UUID) throws -> String?

    /// Deletes the password for a host, if there is one.
    ///
    /// - Throws: `KeychainError` if the password cannot be deleted.
    func deletePassword(for hostID: UUID) throws
}

/// A Keychain operation failed.
struct KeychainError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        SecCopyErrorMessageString(status, nil) as String? ?? "Keychain error \(status)."
    }
}

/// Stores passwords as generic passwords in the user's login Keychain.
struct KeychainPasswordStore: PasswordStore {
    private static let service = "Argus SSH"

    func setPassword(_ password: String, for hostID: UUID) throws {
        try deletePassword(for: hostID)
        var attributes = query(for: hostID)
        attributes[kSecValueData as String] = Data(password.utf8)
        try check(SecItemAdd(attributes as CFDictionary, nil))
    }

    func password(for hostID: UUID) throws -> String? {
        var search = query(for: hostID)
        search[kSecReturnData as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(search as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        try check(status)
        return (item as? Data).flatMap { String(data: $0, encoding: .utf8) }
    }

    func deletePassword(for hostID: UUID) throws {
        let status = SecItemDelete(query(for: hostID) as CFDictionary)
        if status != errSecItemNotFound {
            try check(status)
        }
    }

    private func query(for hostID: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: hostID.uuidString,
        ]
    }

    private func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }
}
