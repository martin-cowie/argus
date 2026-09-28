import AppKit
import SwiftUI

/// A sheet for adding a Unix host reached over SSH.
struct AddHostView: View {
    /// The state of a connection test started from the form.
    enum ConnectionTest: Equatable {
        case running
        case succeeded
        case failed(String)
    }

    /// Saves the new host with its password, if any; an error thrown is shown to the user.
    let onAdd: (RemoteHost, String?) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = HostDraft()
    @State private var saveError: String?
    @State private var connectionTest: ConnectionTest?
    @State private var testTask: Task<Void, Never>?

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

            if let message = problem ?? testFailure {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }

            HStack {
                Button("Test", action: test)
                    .disabled(!draft.isValid || connectionTest == .running)
                testStatus
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
        .onChange(of: draft) {
            testTask?.cancel()
            connectionTest = nil
        }
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

    @ViewBuilder private var testStatus: some View {
        switch connectionTest {
        case nil:
            EmptyView()
        case .running:
            ProgressView().controlSize(.small)
        case .succeeded:
            Label("Connected", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Label("Failed", systemImage: "xmark.octagon.fill").foregroundStyle(.red)
        }
    }

    private var testFailure: String? {
        guard case .failed(let message) = connectionTest else { return nil }
        return message
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

    /// Connects to the host described by the form and runs a no-op command, without saving anything.
    private func test() {
        guard let host = draft.makeHost() else { return }
        let client = SSHClient(host: host, password: draft.passwordToStore)
        testTask?.cancel()
        connectionTest = .running
        testTask = Task {
            let outcome: ConnectionTest
            do {
                _ = try await client.run("true")
                outcome = .succeeded
            } catch {
                outcome = .failed(error.localizedDescription)
            }
            // A change to the form cancels the test, whose outcome no longer describes it.
            if !Task.isCancelled {
                connectionTest = outcome
            }
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
