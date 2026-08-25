//
//  AppBindingsSettingsView.swift
//  switchr
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AppBindingsSettingsView: View {
    @ObservedObject private var customBindings = CustomBindingsStore.shared
    @State private var pendingApp: PendingApp?

    var body: some View {
        Section("App Bindings") {
            if customBindings.bindings.isEmpty {
                Text("No custom bindings. Apps you add here always get your chosen key; other apps are assigned letters automatically.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(customBindings.bindings) { binding in
                HStack(spacing: 10) {
                    Text(binding.key.uppercased())
                        .font(.system(.body, design: .monospaced).weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(width: 26, height: 26)
                        .background(Color.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                    Image(nsImage: NSWorkspace.shared.icon(forFile: binding.appPath))
                        .resizable()
                        .frame(width: 22, height: 22)
                    Text(binding.appName)
                    Spacer()
                    Button {
                        customBindings.remove(binding)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Remove binding")
                }
            }
            Button {
                pickApp()
            } label: {
                Label("Add App…", systemImage: "plus")
            }
        }
        .sheet(item: $pendingApp) { app in
            BindingKeySheet(app: app)
        }
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose an app to bind a key to"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let bundleID = Bundle(url: url)?.bundleIdentifier else {
            let alert = NSAlert()
            alert.messageText = "Not a valid app"
            alert.informativeText = "Couldn't read a bundle identifier from \(url.lastPathComponent)."
            alert.runModal()
            return
        }
        pendingApp = PendingApp(
            bundleID: bundleID,
            name: FileManager.default.displayName(atPath: url.path),
            path: url.path
        )
    }
}

private struct PendingApp: Identifiable {
    let bundleID: String
    let name: String
    let path: String
    var id: String { bundleID }
}

private struct BindingKeySheet: View {
    let app: PendingApp
    @ObservedObject private var store = CustomBindingsStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var saveError: String?
    @FocusState private var keyFieldFocused: Bool

    private var conflict: CustomBinding? {
        store.bindings.first { $0.key == key && $0.bundleID != app.bundleID }
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                    .resizable()
                    .frame(width: 32, height: 32)
                Text(app.name)
                    .font(.headline)
            }

            TextField("Key (letter or number)", text: $key)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
                .multilineTextAlignment(.center)
                .focused($keyFieldFocused)
                .onChange(of: key) { _, newValue in
                    key = String(newValue.lowercased().filter { $0.isLetter || $0.isNumber }.prefix(1))
                    saveError = nil
                }
                .onSubmit(save)

            if let conflict {
                Text("\(key.uppercased()) is already assigned to \(conflict.appName)")
                    .font(.callout)
                    .foregroundStyle(.red)
            } else if let saveError {
                Text(saveError)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add Binding", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(key.isEmpty || conflict != nil)
            }
        }
        .padding(20)
        .frame(width: 320)
        .onAppear { keyFieldFocused = true }
    }

    private func save() {
        guard !key.isEmpty, conflict == nil else { return }
        do {
            try store.add(CustomBinding(bundleID: app.bundleID, appName: app.name, appPath: app.path, key: key))
            dismiss()
        } catch {
            saveError = error.localizedDescription
            NSSound.beep()
        }
    }
}
