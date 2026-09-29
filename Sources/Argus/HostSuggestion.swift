import Foundation

/// A host offered in the Add Host dialog's hostname field.
struct HostSuggestion: Hashable, Sendable {
    let hostname: String
    let port: Int

    /// Combines suggestions from several sources into the list shown to the user.
    ///
    /// - Parameters:
    ///   - sources: The suggestions from each source, most authoritative first; when two sources
    ///     suggest the same hostname, the earlier one's port wins.
    ///   - excluded: Hostnames to leave out, such as hosts already added.
    ///   - query: Text typed so far; only hostnames containing it are kept.
    /// - Returns: One suggestion per hostname, compared without regard to case, sorted by hostname.
    static func merge(_ sources: [[HostSuggestion]], excluding excluded: some Sequence<String>, matching query: String) -> [HostSuggestion] {
        var seen = Set(excluded.map { $0.lowercased() })
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        return sources.joined()
            .filter { seen.insert($0.hostname.lowercased()).inserted }
            .filter { trimmedQuery.isEmpty || $0.hostname.localizedCaseInsensitiveContains(trimmedQuery) }
            .sorted { $0.hostname.localizedStandardCompare($1.hostname) == .orderedAscending }
    }
}

/// Reads hosts from OpenSSH's `known_hosts` file.
enum KnownHosts {
    /// The user's `known_hosts` file.
    static var defaultFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(components: ".ssh", "known_hosts")
    }

    /// Reads the hosts in a `known_hosts` file, off the main actor.
    ///
    /// - Parameter url: The file to read.
    /// - Returns: The hosts, or none if the file is missing or unreadable.
    @concurrent
    static func load(from url: URL = defaultFileURL) async -> [HostSuggestion] {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return hosts(in: contents)
    }

    /// Parses the contents of a `known_hosts` file.
    ///
    /// Only the first name on each line is taken, since OpenSSH lists the name the user typed
    /// before the address it resolved to. Hashed names, wildcard patterns, and certificate
    /// authority and revocation lines are skipped.
    ///
    /// - Parameter contents: The file's contents.
    /// - Returns: The hosts, in file order, each once.
    static func hosts(in contents: String) -> [HostSuggestion] {
        var seen = Set<HostSuggestion>()
        return contents.split(whereSeparator: \.isNewline)
            .compactMap { line in
                guard let field = line.split(whereSeparator: \.isWhitespace).first,
                      !field.hasPrefix("#"), !field.hasPrefix("@"), !field.hasPrefix("|"),
                      let name = field.split(separator: ",").first
                else { return nil }
                return suggestion(from: name)
            }
            .filter { seen.insert($0).inserted }
    }

    private static func suggestion(from name: Substring) -> HostSuggestion? {
        guard !name.contains(where: { "*?!".contains($0) }) else { return nil }
        // A non-standard port is written as `[host]:port`.
        if name.hasPrefix("["), let close = name.firstIndex(of: "]") {
            let host = name[name.index(after: name.startIndex)..<close]
            let port = name[close...].dropFirst().split(separator: ":").first.flatMap { Int($0) }
            guard !host.isEmpty, let port, HostAddress.validPorts.contains(port) else { return nil }
            return HostSuggestion(hostname: String(host), port: port)
        }
        return HostSuggestion(hostname: String(name), port: RemoteHost.defaultPort)
    }
}
