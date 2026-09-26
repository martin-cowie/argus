import SwiftUI
import Testing
@testable import Argus

@MainActor
@Test func contentViewBuilds() {
    _ = ContentView().body
}
