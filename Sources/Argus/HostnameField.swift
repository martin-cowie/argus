import SwiftUI

/// A hostname text field with a pull-down menu of suggested hosts, grouped by where they were found.
struct HostnameField: View {
    @Binding var text: String
    /// Hosts advertising SSH on the local network.
    let localNetworkHosts: [HostSuggestion]
    /// Hosts from `~/.ssh/known_hosts`.
    let knownHosts: [HostSuggestion]
    /// Called when the user picks a suggestion, after `text` is set to its hostname.
    let onChoose: (HostSuggestion) -> Void

    var body: some View {
        HStack(spacing: 4) {
            TextField("Hostname or IP address", text: $text, prompt: Text("server.example.com"))
                .labelsHidden()
            Menu {
                section("Local Network", localNetworkHosts)
                section("Known Hosts", knownHosts)
            } label: {
                Image(systemName: "chevron.down")
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(localNetworkHosts.isEmpty && knownHosts.isEmpty)
            .help("Choose a Host")
        }
    }

    @ViewBuilder private func section(_ title: String, _ hosts: [HostSuggestion]) -> some View {
        if !hosts.isEmpty {
            Section(title) {
                ForEach(hosts, id: \.self) { host in
                    Button(host.port == RemoteHost.defaultPort ? host.hostname : "\(host.hostname):\(host.port)") {
                        text = host.hostname
                        onChoose(host)
                    }
                }
            }
        }
    }
}
