import Foundation
import SwiftUI
import Testing
@testable import Argus

@MainActor
@Test func contentViewBuilds() {
    let store = HostStore(fileURL: temporaryHostsFile(), passwords: InMemoryPasswordStore())
    _ = ContentView(store: store).body
}
