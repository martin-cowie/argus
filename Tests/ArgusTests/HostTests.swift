import Foundation
import Testing
@testable import Argus

@Suite struct HostAddressTests {
    @Test(arguments: ["server", "server.example.com", "server.example.com.", "a-b.c1", "192.168.1.10", "::1", "fe80::1"])
    func acceptsValidAddresses(address: String) {
        #expect(HostAddress.isValid(address))
    }

    @Test(arguments: ["", ".", "-server", "server-", "ser ver", "server..com", "user@server", "256.1.1.1", "10.0.0", String(repeating: "a", count: 64)])
    func rejectsInvalidAddresses(address: String) {
        #expect(!HostAddress.isValid(address))
    }
}

@Suite struct HostTests {
    @Test func displayNameOmitsDefaultPort() {
        let host = RemoteHost(id: UUID(), hostname: "nas", port: 22, username: "pi", authentication: .password)
        #expect(host.displayName == "pi@nas")
    }

    @Test func displayNameShowsOtherPorts() {
        let host = RemoteHost(id: UUID(), hostname: "nas", port: 2222, username: "pi", authentication: .password)
        #expect(host.displayName == "pi@nas:2222")
    }
}

@Suite struct HostDraftTests {
    private func passwordDraft() -> HostDraft {
        var result = HostDraft()
        result.hostname = " nas.local "
        result.username = "pi"
        result.method = .password
        result.password = "secret"
        return result
    }

    @Test func defaultsToPort22AndKeyAuthentication() {
        let draft = HostDraft()
        #expect(draft.port == 22)
        #expect(draft.method == .key)
    }

    @Test func makesTrimmedHost() throws {
        let host = try #require(passwordDraft().makeHost())
        #expect(host.hostname == "nas.local")
        #expect(host.port == 22)
        #expect(host.authentication == .password)
    }

    @Test func storesPasswordOnlyForPasswordAuthentication() {
        var draft = passwordDraft()
        #expect(draft.passwordToStore == "secret")
        draft.method = .key
        #expect(draft.passwordToStore == nil)
    }

    @Test(arguments: [0, 65536])
    func rejectsPortsOutOfRange(port: Int) {
        var draft = passwordDraft()
        draft.port = port
        #expect(draft.makeHost() == nil)
    }

    @Test func rejectsEmptyPassword() {
        var draft = passwordDraft()
        draft.password = ""
        #expect(draft.makeHost() == nil)
    }

    @Test func rejectsMissingKeyFile() {
        var draft = passwordDraft()
        draft.method = .key
        draft.keyPath = "/nonexistent/id_ed25519"
        #expect(draft.makeHost() == nil)
    }

    @Test func acceptsReadableKeyFile() throws {
        let keyFile = temporaryHostsFile().deletingLastPathComponent().appendingPathComponent("id_test")
        try FileManager.default.createDirectory(at: keyFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("key".utf8).write(to: keyFile)
        var draft = passwordDraft()
        draft.method = .key
        draft.keyPath = keyFile.path
        #expect(draft.makeHost()?.authentication == .key(path: keyFile.path))
    }
}

@MainActor
@Suite struct HostStoreTests {
    private let fileURL = temporaryHostsFile()
    private let passwords = InMemoryPasswordStore()

    private func makeHost(_ authentication: RemoteHost.Authentication = .password) -> RemoteHost {
        RemoteHost(id: UUID(), hostname: "nas", port: 22, username: "pi", authentication: authentication)
    }

    @Test func startsEmptyWithoutFile() {
        #expect(HostStore(fileURL: fileURL, passwords: passwords).hosts.isEmpty)
    }

    @Test func persistsAddedHosts() throws {
        let host = makeHost(.key(path: "/keys/id"))
        try HostStore(fileURL: fileURL, passwords: passwords).add(host, password: nil)
        #expect(HostStore(fileURL: fileURL, passwords: passwords).hosts == [host])
    }

    @Test func keepsPasswordInPasswordStore() throws {
        let host = makeHost()
        let store = HostStore(fileURL: fileURL, passwords: passwords)
        try store.add(host, password: "secret")
        #expect(try store.password(for: host) == "secret")
        #expect(try !String(contentsOf: fileURL, encoding: .utf8).contains("secret"))
    }

    @Test func removesHostAndPassword() throws {
        let host = makeHost()
        let store = HostStore(fileURL: fileURL, passwords: passwords)
        try store.add(host, password: "secret")
        try store.remove(host)
        #expect(store.hosts.isEmpty)
        #expect(try store.password(for: host) == nil)
        #expect(HostStore(fileURL: fileURL, passwords: passwords).hosts.isEmpty)
    }

    @Test func movesUnreadableFileAside() throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: fileURL)
        #expect(HostStore(fileURL: fileURL, passwords: passwords).hosts.isEmpty)
        #expect(FileManager.default.fileExists(atPath: fileURL.appendingPathExtension("unreadable").path))
    }
}
