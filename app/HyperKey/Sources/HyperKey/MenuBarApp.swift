import SwiftUI

@main
struct HyperKeyApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("HyperKey", systemImage: model.isRunning ? "keyboard.fill" : "keyboard") {
            MenuBarContent(model: model)
        }
        .menuBarExtraStyle(.menu)

        Window("HyperKey Settings", id: "settings") {
            SettingsView(model: model)
                .frame(minWidth: 720, minHeight: 480)
        }
        .windowResizability(.contentMinSize)
    }
}

struct MenuBarContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            if model.isRunning {
                Text("HyperKey is active")
            } else if !model.hasAccessibility || !model.hasInputMonitoring {
                Text("Permissions needed")
            } else {
                Text("HyperKey is paused")
            }

            Divider()

            Button(model.isRunning ? "Pause" : "Start") {
                model.toggleEngine()
            }

            Button("Settings…") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",")

            Divider()

            Button("Quit HyperKey") {
                model.engine.stop()
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .onAppear { model.startIfPermitted() }
    }
}
