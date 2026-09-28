import AppKit
import SwiftUI

/// The main window's root view.
struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            List {
                Label("Overview", systemImage: "eye")
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            ContentUnavailableView {
                Image(nsImage: Bundle.resources.image(forResource: "Logo") ?? NSImage())
                    .resizable()
                    .scaledToFit()
                    .frame(width: 320)
            } description: {
                Text("Nothing to watch yet.")
            }
        }
    }
}
