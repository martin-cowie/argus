import Foundation

extension Bundle {
    /// The Argus target's resource bundle.
    ///
    /// SwiftPM's generated `Bundle.module` looks for the resource bundle in the root of the `.app`,
    /// where code signing forbids it, so the packaged app keeps it in `Contents/Resources` instead.
    static let resources: Bundle = Bundle.main.resourceURL
        .map { $0.appendingPathComponent("argus_Argus.bundle") }
        .flatMap(Bundle.init(url:))
        ?? .module
}
