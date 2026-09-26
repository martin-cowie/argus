import AppKit
import SwiftUI

/// Entry point for the Argus desktop application.
@main
struct ArgusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var hosts = HostStore()

    var body: some Scene {
        WindowGroup("Argus") {
            ContentView(store: hosts)
        }
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Argus", action: AboutPanel.show)
            }
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
