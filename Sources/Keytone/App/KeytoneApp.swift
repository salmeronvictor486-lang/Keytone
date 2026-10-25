import AppKit
import SwiftUI

@main
struct KeytoneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var prefs = AppState.shared.prefs

    var body: some Scene {
        MenuBarExtra {
            MenuView()
        } label: {
            Image(systemName: prefs.enabled ? "keyboard.fill" : "keyboard")
                .accessibilityLabel("Keytone")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let state = AppState.shared
        state.start()
        if !state.prefs.completedOnboarding || !state.hasPermission {
            WindowManager.shared.showSettings(.welcome)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppState.shared.stats.save()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WindowManager.shared.showSettings()
        return true
    }
}

/// Ventana de ajustes gestionada con AppKit: funciona igual en macOS 13, 14 y 15.
@MainActor
final class WindowManager {
    static let shared = WindowManager()
    private var window: NSWindow?

    func showSettings(_ section: SettingsSection? = nil) {
        if let section { AppState.shared.settingsSection = section }
        if window == nil {
            let controller = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: controller)
            window.title = "Keytone"
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 780, height: 540))
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
