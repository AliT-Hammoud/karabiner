import SwiftUI

/// Sidebar selection for the settings window.
private enum Pane: Hashable {
    case general
    case direct
    case sublayer(UUID)
    case overrides
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var selection: Pane? = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("General", systemImage: "gearshape").tag(Pane.general)

                Section("Hyper + key") {
                    Label("Direct bindings", systemImage: "command").tag(Pane.direct)
                }

                Section("Sublayers (Hyper + trigger + key)") {
                    ForEach(model.config.sublayers) { sub in
                        Label("\(sub.trigger.uppercased())  ·  \(sub.name)", systemImage: "square.stack")
                            .tag(Pane.sublayer(sub.id))
                    }
                }

                Section("App-specific") {
                    Label("App overrides", systemImage: "app.badge").tag(Pane.overrides)
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 240)
        } detail: {
            detail
        }
        .onChange(of: model.config) { model.save() }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .general, nil:
            GeneralPane(model: model)
        case .direct:
            BindingsEditor(title: "Direct Hyper bindings",
                           subtitle: "Fire on Hyper + key.",
                           bindings: $model.config.directBindings)
        case .sublayer(let id):
            if let idx = model.config.sublayers.firstIndex(where: { $0.id == id }) {
                BindingsEditor(title: "\(model.config.sublayers[idx].name) (Hyper + \(model.config.sublayers[idx].trigger.uppercased()))",
                               subtitle: "Fire on Hyper + \(model.config.sublayers[idx].trigger.uppercased()) + key.",
                               bindings: $model.config.sublayers[idx].bindings)
            } else {
                Text("Select a sublayer")
            }
        case .overrides:
            OverridesEditor(overrides: $model.config.appOverrides)
        }
    }
}

// MARK: - General

private struct GeneralPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Status") {
                LabeledContent("Engine") {
                    HStack {
                        Circle().fill(model.isRunning ? .green : .secondary).frame(width: 8, height: 8)
                        Text(model.isRunning ? "Active" : "Paused")
                        Spacer()
                        Button(model.isRunning ? "Pause" : "Start") { model.toggleEngine() }
                    }
                }
            }

            Section("Permissions") {
                permissionRow(
                    "Accessibility",
                    granted: model.hasAccessibility,
                    hint: "Required to read/modify key events and manage windows.",
                    action: { model.requestAccessibility() }
                )
                permissionRow(
                    "Input Monitoring",
                    granted: model.hasInputMonitoring,
                    hint: "Required to observe the keyboard.",
                    action: { model.requestInputMonitoring() }
                )
                Button("Re-check permissions") { model.refreshPermissions() }
            }

            Section("Startup") {
                Toggle("Launch HyperKey at login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
            }

            Section("Config") {
                LabeledContent("File", value: model.configPath)
                    .textSelection(.enabled)
                Button("Reset to defaults", role: .destructive) { model.resetToDefault() }
            }

            Section {
                Text("Caps Lock is remapped to Hyper (⌃⌥⇧⌘). Tap it alone for Escape. While running, disable or quit Karabiner-Elements to avoid double handling.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }

    @ViewBuilder
    private func permissionRow(_ name: String, granted: Bool, hint: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(granted ? .green : .orange)
                Text(name)
                Spacer()
                if !granted { Button("Grant…", action: action) }
            }
            Text(hint).font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Bindings editor

private struct BindingsEditor: View {
    let title: String
    let subtitle: String
    @Binding var bindings: [KeyBinding]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title3).bold()
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            .padding()

            List {
                ForEach($bindings) { $binding in
                    BindingRow(binding: $binding)
                }
                .onDelete { bindings.remove(atOffsets: $0) }
            }

            HStack {
                Button {
                    bindings.append(KeyBinding(key: "", action: ActionSpec(type: .keystroke)))
                } label: { Label("Add binding", systemImage: "plus") }
                Spacer()
            }
            .padding()
        }
        .navigationTitle(title)
    }
}

private struct BindingRow: View {
    @Binding var binding: KeyBinding

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Trigger key").frame(width: 90, alignment: .leading)
                    TextField("e.g. g, semicolon, spacebar", text: $binding.key)
                        .textFieldStyle(.roundedBorder).frame(width: 220)
                }
                TextField("Description", text: $binding.description)
                ActionEditor(action: $binding.action)
            }
            .padding(.vertical, 4)
        } label: {
            HStack {
                Text(keyLabel).font(.system(.body, design: .monospaced)).bold()
                    .frame(minWidth: 70, alignment: .leading)
                Text(binding.description.isEmpty ? binding.action.summary : binding.description)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var keyLabel: String {
        binding.key.isEmpty ? "—" : binding.key.replacingOccurrences(of: "_", with: " ")
    }
}

// MARK: - Action editor

private struct ActionEditor: View {
    @Binding var action: ActionSpec

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Action", selection: $action.type) {
                ForEach(ActionType.allCases) { Text($0.label).tag($0) }
            }
            .frame(width: 320)

            fields
        }
    }

    @ViewBuilder
    private var fields: some View {
        switch action.type {
        case .keystroke:
            HStack {
                Text("Key").frame(width: 90, alignment: .leading)
                TextField("e.g. left_arrow, tab", text: Binding(
                    get: { action.key ?? "" }, set: { action.key = $0 }))
                    .textFieldStyle(.roundedBorder).frame(width: 220)
            }
            HStack {
                Text("Modifiers").frame(width: 90, alignment: .leading)
                TextField("comma-separated: command, shift…", text: Binding(
                    get: { action.modifiers.joined(separator: ", ") },
                    set: { action.modifiers = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }))
                    .textFieldStyle(.roundedBorder).frame(width: 320)
            }
        case .media:
            Picker("Media", selection: Binding(
                get: { action.media ?? .playPause }, set: { action.media = $0 })) {
                ForEach(MediaKey.allCases) { Text($0.rawValue).tag($0) }
            }.frame(width: 320)
        case .launchApp, .pickWindow:
            HStack {
                Text("App name").frame(width: 90, alignment: .leading)
                TextField("e.g. Visual Studio Code", text: Binding(
                    get: { action.app ?? "" }, set: { action.app = $0 }))
                    .textFieldStyle(.roundedBorder).frame(width: 220)
            }
        case .openURL:
            HStack {
                Text("URL").frame(width: 90, alignment: .leading)
                TextField("https:// or raycast://", text: Binding(
                    get: { action.url ?? "" }, set: { action.url = $0 }))
                    .textFieldStyle(.roundedBorder).frame(width: 320)
            }
        case .window:
            Picker("Window", selection: Binding(
                get: { action.window ?? .maximize }, set: { action.window = $0 })) {
                ForEach(WindowAction.allCases) { Text($0.rawValue).tag($0) }
            }.frame(width: 320)
        case .shell:
            HStack {
                Text("Command").frame(width: 90, alignment: .leading)
                TextField("shell command", text: Binding(
                    get: { action.command ?? "" }, set: { action.command = $0 }))
                    .textFieldStyle(.roundedBorder).frame(width: 320)
            }
        }
    }
}

// MARK: - App overrides

private struct OverridesEditor: View {
    @Binding var overrides: [AppOverride]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("App overrides").font(.title3).bold()
                Text("Remap a key only while a matching app is frontmost.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()

            List {
                ForEach($overrides) { $o in
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Name", text: $o.name)
                        HStack {
                            TextField("Bundle id / path contains", text: $o.bundleIdContains)
                            TextField("From key", text: $o.fromKey).frame(width: 140)
                            Image(systemName: "arrow.right")
                            TextField("To key", text: $o.toKey).frame(width: 140)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { overrides.remove(atOffsets: $0) }
            }

            HStack {
                Button {
                    overrides.append(AppOverride(name: "", bundleIdContains: "", fromKey: "", toKey: ""))
                } label: { Label("Add override", systemImage: "plus") }
                Spacer()
            }
            .padding()
        }
        .navigationTitle("App overrides")
    }
}
