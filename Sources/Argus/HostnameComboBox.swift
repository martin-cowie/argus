import AppKit
import SwiftUI

/// A text field with a drop-down of suggested hosts, which also accepts any text typed.
struct HostnameComboBox: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let suggestions: [HostSuggestion]
    /// Called when the user picks a suggestion from the list.
    let onChoose: (HostSuggestion) -> Void

    func makeNSView(context: Context) -> NSComboBox {
        let result = NSComboBox()
        result.completes = true
        result.numberOfVisibleItems = 10
        result.placeholderString = placeholder
        result.delegate = context.coordinator
        return result
    }

    func updateNSView(_ comboBox: NSComboBox, context: Context) {
        context.coordinator.parent = self
        let hostnames = suggestions.map(\.hostname)
        if comboBox.objectValues as? [String] != hostnames {
            comboBox.removeAllItems()
            comboBox.addItems(withObjectValues: hostnames)
        }
        // Rewriting the text mid-edit would discard the inline completion being offered.
        if comboBox.currentEditor() == nil, comboBox.stringValue != text {
            comboBox.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    /// Relays edits and choices from the combo box to SwiftUI.
    final class Coordinator: NSObject, NSComboBoxDelegate {
        var parent: HostnameComboBox

        init(parent: HostnameComboBox) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            parent.text = comboBox.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            parent.text = comboBox.stringValue
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox,
                  parent.suggestions.indices.contains(comboBox.indexOfSelectedItem)
            else { return }
            let suggestion = parent.suggestions[comboBox.indexOfSelectedItem]
            parent.text = suggestion.hostname
            parent.onChoose(suggestion)
        }
    }
}
