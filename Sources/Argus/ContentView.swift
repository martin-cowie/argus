import AppKit
import SwiftUI

/// The main window's root view: hosts in the sidebar, monitored hosts in the detail pane.
struct ContentView: View {
    let hosts: HostStore
    let monitors: MonitorStore

    @State private var selection = Set<RemoteHost.ID>()
    @State private var isAddingHost = false
    @State private var removeError: String?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Hosts") {
                    ForEach(hosts.hosts) { host in
                        Label(host.displayName, systemImage: "server.rack")
                            .tag(host.id)
                            .help(host.authenticationDescription)
                    }
                }
            }
            .contextMenu(forSelectionType: RemoteHost.ID.self) { ids in
                if !ids.isEmpty {
                    Button("Monitor") { monitors.monitor(hosts.hosts.filter { ids.contains($0.id) }) }
                    Divider()
                    Button("Remove", role: .destructive) { remove(ids) }
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
            if !monitors.monitors.isEmpty {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(monitors.monitors) { monitor in
                            MonitorPanel(monitor: monitor) { monitors.stop(monitor.id) }
                        }
                    }
                    .padding()
                }
            } else if hosts.hosts.isEmpty {
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
                ContentUnavailableView(
                    "Argus",
                    systemImage: "eye",
                    description: Text("Select hosts and choose Monitor from their context menu.")
                )
            }
        }
        .sheet(isPresented: $isAddingHost) {
            AddHostView { host, password in
                try hosts.add(host, password: password)
                selection = [host.id]
            }
        }
        .alert("Couldn't Remove Host", isPresented: .constant(removeError != nil), presenting: removeError) { _ in
            Button("OK") { removeError = nil }
        } message: { message in
            Text(message)
        }
    }

    private func remove(_ ids: Set<RemoteHost.ID>) {
        do {
            for host in hosts.hosts where ids.contains(host.id) {
                monitors.stop(host.id)
                try hosts.remove(host)
                selection.remove(host.id)
            }
        } catch {
            removeError = error.localizedDescription
        }
    }
}

/// A monitored host's details, with a button to stop monitoring it.
struct MonitorPanel: View {
    let monitor: HostMonitor
    let onClose: () -> Void

    var body: some View {
        GroupBox {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
        } label: {
            HStack {
                Label(monitor.host.displayName, systemImage: "server.rack")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Label("Stop Monitoring", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Stop Monitoring")
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch monitor.status {
        case .connecting:
            ProgressView("Connecting…")
                .controlSize(.small)
        case .connected(let system):
            Grid(alignment: .leading) {
                GridRow {
                    Text("Operating system").foregroundStyle(.secondary)
                    Text(system.name)
                }
                GridRow {
                    Text("Version").foregroundStyle(.secondary)
                    Text(system.version)
                }
            }
            .textSelection(.enabled)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        }
    }
}

private extension RemoteHost {
    var authenticationDescription: String {
        switch authentication {
        case .key(let path): "Private key \(NSString(string: path).abbreviatingWithTildeInPath)"
        case .password: "Password (in Keychain)"
        }
    }
}
