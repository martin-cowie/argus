import AppKit

/// The standard About panel, with a note on the legend behind the app's name.
@MainActor
enum AboutPanel {
    /// The story of Argus Panoptes, shown as the About panel's credits.
    static let legend = """
        Argus takes its name from Argus Panoptes, the all-seeing giant of Greek myth, \
        whose body was covered in eyes: a hundred, some say a thousand. \
        Hera set him to watch over Io, and as some of his eyes were always awake, \
        nothing escaped him. When Hermes lulled him to sleep and slew him, \
        Hera placed his eyes in the peacock's tail.
        """

    /// Shows the About panel.
    static func show() {
        NSApp.orderFrontStandardAboutPanel(options: options(infoDictionary: Bundle.main.infoDictionary))
        NSApp.activate()
    }

    /// Builds the About panel options.
    ///
    /// - Parameter infoDictionary: The main bundle's Info.plist, if any. A bare SwiftPM
    ///   executable has none, so the name and version are supplied explicitly.
    /// - Returns: Options for `orderFrontStandardAboutPanel(options:)`.
    static func options(infoDictionary: [String: Any]?) -> [NSApplication.AboutPanelOptionKey: Any] {
        var result: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: "Argus",
            .credits: credits(),
        ]
        if let version = infoDictionary?["CFBundleShortVersionString"] as? String {
            result[.applicationVersion] = version
        }
        return result
    }

    private static func credits() -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        return NSAttributedString(
            string: legend,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraph,
            ]
        )
    }
}
