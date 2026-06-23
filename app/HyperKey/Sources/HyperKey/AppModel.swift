import AppKit
import SwiftUI
import ServiceManagement
import IOKit.hid

/// Top-level app state: owns the config, the keyboard engine, permission status,
/// and login-item registration. Drives the menu bar and settings UI.
@MainActor
final class AppModel: ObservableObject {
    @Published var config: Config
    @Published var hasAccessibility = false
    @Published var hasInputMonitoring = false
    @Published var launchAtLogin = false

    let engine: KeyboardEngine
    private var permissionTimer: Timer?

    init() {
        let loaded = ConfigStore.shared.load()
        self.config = loaded
        self.engine = KeyboardEngine(config: loaded)
        refreshPermissions()
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
    }

    var isRunning: Bool { engine.isRunning }
    var configPath: String { ConfigStore.shared.path }

    // MARK: - Engine

    func startIfPermitted() {
        refreshPermissions()
        guard hasAccessibility && hasInputMonitoring else { return }
        engine.start()
        objectWillChange.send()
    }

    func toggleEngine() {
        if engine.isRunning {
            engine.stop()
        } else {
            startIfPermitted()
        }
        objectWillChange.send()
    }

    // MARK: - Config persistence

    func save() {
        ConfigStore.shared.save(config)
        engine.updateConfig(config)
    }

    func resetToDefault() {
        config = .default
        save()
    }

    // MARK: - Permissions

    func refreshPermissions() {
        hasAccessibility = AXIsProcessTrusted()
        hasInputMonitoring = (IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted)
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        openSettings(pane: "Privacy_Accessibility")
        startPermissionPolling()
    }

    func requestInputMonitoring() {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        openSettings(pane: "Privacy_ListenEvent")
        startPermissionPolling()
    }

    private func openSettings(pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Poll until both permissions are granted, then auto-start the engine.
    private func startPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                self.refreshPermissions()
                if self.hasAccessibility && self.hasInputMonitoring {
                    timer.invalidate()
                    self.permissionTimer = nil
                    if !self.engine.isRunning { self.startIfPermitted() }
                }
            }
        }
    }

    // MARK: - Launch at login

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
        } catch {
            NSLog("HyperKey: launch-at-login toggle failed: \(error)")
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }
}
