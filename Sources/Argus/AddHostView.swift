import AppKit
import SwiftUI

/// A sheet for adding a Unix host reached over SSH.
struct AddHostView: View {
    /// Saves the new host with its password, if any; an error thrown is shown to the user.
    let onAdd: (RemoteHost, String?) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = HostDraft()
    @State private var saveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section {
                    TextField("Hostname or IP address", text: $draft.hostname, prompt: Text("server.example.com"))
                    TextField("Port", value: $draft.port, format: .number.grouping(.never))
                    TextField("Username", text: $draft.username)
                }
                Section {
                    Picker("Authenticate with", selection: $draft.method) {
                        Text("Private key").tag(HostDraft.Method.key)
                        Text("Password").tag(HostDraft.Method.password)
                    }
                    .pickerStyle(.segmented)
                    credentialField
                }
            }
            .formStyle(.grouped)

            if let problem {
                Text(problem)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add", action: add)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!draft.isValid)
            }
            .padding(20)
        }
        .frame(width: 460)
        .navigationTitle("Add Host")
        .alert("Couldn't Add Host", isPresented: .constant(saveError != nil), presenting: saveError) { _ in
            Button("OK") { saveError = nil }
        } message: { message in
            Text(message)
        }
    }

    @ViewBuilder private var credentialField: some View {
        switch draft.method {
        case .key:
            HStack {
                TextField("Key file", text: $draft.keyPath, prompt: Text("~/.ssh/id_ed25519"))
                Button("Choose…", action: chooseKey)
            }
        case .password:
            SecureField("Password", text: $draft.password)
        }
    }

    /// The first thing stopping the form being submitted, once the user has typed something.
    private var problem: String? {
        if draft.hostname.isEmpty {
            return nil
        }
        if !draft.hostnameIsValid {
            return "Enter a valid hostname or IP address."
        }
        if !draft.portIsValid {
            return "The port must be between 1 and 65535."
        }
        if !draft.usernameIsValid {
            return "Enter a username."
        }
        if !draft.credentialIsValid {
            return draft.method == .key ? "Choose a readable private key file." : "Enter a password."
        }
        return nil
    }

    private func add() {
        guard let host = draft.makeHost() else { return }
        do {
            try onAdd(host, draft.passwordToStore)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func chooseKey() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Private Key"
        panel.showsHiddenFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
        if panel.runModal() == .OK, let url = panel.url {
            draft.keyPath = url.path
        }
    }
}
