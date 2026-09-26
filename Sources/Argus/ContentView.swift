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
            ContentUnavailableView("Argus", systemImage: "eye", description: Text("Nothing to watch yet."))
        }
    }
}
