import AppKit
import SwiftUI

/// Entry point for the Argus desktop application.
@main
struct ArgusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var hosts: HostStore
    @State private var monitors: MonitorStore
    @State private var dockIcon: DockIcon
    @AppStorage("showsLoadInDock") private var showsLoadInDock = false

    init() {
        let hosts = HostStore()
        _hosts = State(initialValue: hosts)
        let monitors = MonitorStore { host in
            SSHClient(host: host, password: try await hosts.password(for: host))
        }
        _monitors = State(initialValue: monitors)
        _dockIcon = State(initialValue: DockIcon(monitors: monitors))
    }

    var body: some Scene {
        WindowGroup("Argus") {
            ContentView(hosts: hosts, monitors: monitors)
        }
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Argus", action: AboutPanel.show)
            }
            CommandGroup(after: .sidebar) {
                Toggle("Show Load in Dock Icon", isOn: $showsLoadInDock)
            }
        }
        .onChange(of: showsLoadInDock, initial: true) {
            dockIcon.showsLoad = showsLoadInDock
        }
    }
}

/// Makes the app behave as a regular foreground application.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // A bare SwiftPM executable has no Info.plist, so it launches as a background process
        // without a Dock icon or key window unless promoted explicitly.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
