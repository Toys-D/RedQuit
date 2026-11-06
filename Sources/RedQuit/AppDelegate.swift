import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let prefs = Preferences()
    private let permissions = PermissionManager()
    private lazy var engine = Engine(prefs: prefs)

    private var statusMenu: StatusMenuController?
    private var settingsWindow: NSWindow?
    private var permissionWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        Log.app.notice("RedQuit \(version, privacy: .public) запущен: \(Bundle.main.bundlePath, privacy: .public)")

        // RedQuit работает без окон. Без этого macOS считает такую программу «простаивающей»
        // и может тихо завершить её (Automatic Termination).
        ProcessInfo.processInfo.disableAutomaticTermination("RedQuit следит за красными кнопками")

        let menu = StatusMenuController(prefs: prefs, permissions: permissions)
        menu.onOpenSettings = { [weak self] in self?.showSettings() }
        menu.onRequestPermission = { [weak self] in self?.showPermissionWindow() }
        statusMenu = menu

        prefs.onChange = { [weak self] in self?.refresh() }
        permissions.onChange = { [weak self] trusted in self?.permissionChanged(trusted) }
        permissions.start()
        refresh()

        if !permissions.isTrusted {
            showPermissionWindow()
        }
    }

    /// Повторный запуск уже работающего RedQuit (например, двойной щелчок в Finder) — открываем настройки.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Состояние

    private func refresh() {
        engine.setActive(prefs.isEnabled && permissions.isTrusted)
        statusMenu?.update()
    }

    private func permissionChanged(_ trusted: Bool) {
        refresh()
        if trusted, let window = permissionWindow, window.isVisible {
            // Даём увидеть «Доступ получен», затем закрываем окно.
            Task { @MainActor [weak window] in
                try? await Task.sleep(for: .seconds(2))
                window?.close()
            }
        }
    }

    // MARK: - Окна

    private func showSettings() {
        if settingsWindow == nil {
            settingsWindow = makeWindow(
                title: "Настройки RedQuit",
                view: SettingsView(prefs: prefs, permissions: permissions),
                resizable: true
            )
        }
        present(settingsWindow)
    }

    private func showPermissionWindow() {
        if permissionWindow == nil {
            permissionWindow = makeWindow(
                title: "RedQuit — Универсальный доступ",
                view: PermissionView(permissions: permissions) { [weak self] in self?.permissionWindow?.close() },
                resizable: false
            )
        }
        present(permissionWindow)
    }

    private func makeWindow<Content: View>(title: String, view: Content, resizable: Bool) -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = title
        window.styleMask = resizable ? [.titled, .closable, .resizable] : [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private func present(_ window: NSWindow?) {
        guard let window else { return }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}
