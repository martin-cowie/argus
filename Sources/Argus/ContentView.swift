import AppKit
import SwiftUI

/// The main window's root view: hosts in the sidebar, the selected host in the detail pane.
struct ContentView: View {
    let store: HostStore

    @State private var selection: RemoteHost.ID?
    @State private var isAddingHost = false
    @State private var removeError: String?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Hosts") {
                    ForEach(store.hosts) { host in
                        Label(host.displayName, systemImage: "server.rack")
                            .tag(host.id)
                            .contextMenu {
                                Button("Remove", role: .destructive) { remove(host) }
                            }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Button {
                        isAddingHost = true
                    } label: {
                        Label("Add Host", systemImage: "plus")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .help("Add Host")
                    Spacer()
                }
                .padding(8)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            if let host = store.hosts.first(where: { $0.id == selection }) {
                HostDetailView(host: host)
            } else if store.hosts.isEmpty {
                ContentUnavailableView {
                    Image(nsImage: Bundle.resources.image(forResource: "Logo") ?? NSImage())
                        .resizable()
                        .scaledToFit()
                        .frame(width: 320)
                } description: {
                    Text("Add a host to start watching it.")
                } actions: {
                    Button("Add Host…") { isAddingHost = true }
                }
            } else {
                ContentUnavailableView("Argus", systemImage: "eye", description: Text("Select a host."))
            }
        }
        .sheet(isPresented: $isAddingHost) {
            AddHostView { host, password in
                try store.add(host, password: password)
                selection = host.id
            }
        }
        .alert("Couldn't Remove Host", isPresented: .constant(removeError != nil), presenting: removeError) { _ in
            Button("OK") { removeError = nil }
        } message: { message in
            Text(message)
        }
    }

    private func remove(_ host: RemoteHost) {
        do {
            try store.remove(host)
            if selection == host.id {
                selection = nil
            }
        } catch {
            removeError = error.localizedDescription
        }
    }
}

/// Summarises a host's connection settings.
struct HostDetailView: View {
    let host: RemoteHost

    var body: some View {
        Form {
            LabeledContent("Hostname", value: host.hostname)
            LabeledContent("Port", value: String(host.port))
            LabeledContent("Username", value: host.username)
            LabeledContent("Authentication", value: authenticationDescription)
        }
        .formStyle(.grouped)
        .navigationTitle(host.displayName)
    }

    private var authenticationDescription: String {
        switch host.authentication {
        case .key(let path): "Private key \(NSString(string: path).abbreviatingWithTildeInPath)"
        case .password: "Password (in Keychain)"
        }
    }
}
