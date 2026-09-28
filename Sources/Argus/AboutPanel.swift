import AppKit

/// The standard About panel, credited to Argus's mythological namesake.
@MainActor
enum AboutPanel {
    static let namesakeURL = URL(string: "https://en.wikipedia.org/wiki/Argus_Panoptes")!

    /// The panel's credits: a centred line linking to the namesake's Wikipedia article.
    static var credits: NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let result = NSAttributedString(string: "Argus of the thousand eyes", attributes: [
            .link: namesakeURL,
            .paragraphStyle: paragraph,
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
        ])
        return result
    }

    /// Shows the About panel and brings the app to the front.
    ///
    /// The panel uses the application icon, which only the packaged `.app` has.
    static func show() {
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
        NSApp.activate()
    }
}
