import AppKit
import RedQuitCore

/// Значок и меню в строке меню.
@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    var onOpenSettings: (@MainActor () -> Void)?
    var onRequestPermission: (@MainActor () -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let prefs: Preferences
    private let permissions: PermissionManager

    init(prefs: Preferences, permissions: PermissionManager) {
        self.prefs = prefs
        self.permissions = permissions
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        update()
    }

    private var statusText: String {
        if !permissions.isTrusted { return L10n.statusNeedsAccess }
        if !prefs.isEnabled { return L10n.statusPaused }
        return L10n.statusOn(L10n.modeTitle(prefs.mode))
    }

    /// Обновляет значок: работает / пауза (приглушён) / нет доступа (треугольник).
    func update() {
        let image: NSImage?
        if !permissions.isTrusted {
            image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: statusText)
            image?.isTemplate = true
        } else {
            image = StatusIcon.image(dimmed: !prefs.isEnabled)
            image?.accessibilityDescription = statusText
        }
        statusItem.button?.image = image
        statusItem.button?.toolTip = statusText
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        if !permissions.isTrusted {
            menu.addItem(item(L10n.menuGrantAccess, #selector(requestPermission)))
        }

        menu.addItem(.separator())
        menu.addItem(item(prefs.isEnabled ? L10n.menuPause : L10n.menuResume, #selector(toggleEnabled)))

        let modeItem = NSMenuItem(title: L10n.menuMode, action: nil, keyEquivalent: "")
        let modeMenu = NSMenu()
        modeMenu.autoenablesItems = false
        for mode in QuitMode.allCases {
            let modeChoice = item(L10n.modeTitle(mode), #selector(selectMode(_:)))
            modeChoice.representedObject = mode.rawValue
            modeChoice.state = prefs.mode == mode ? .on : .off
            modeChoice.toolTip = L10n.modeExplanation(mode)
            modeMenu.addItem(modeChoice)
        }
        modeItem.submenu = modeMenu
        menu.addItem(modeItem)

        menu.addItem(.separator())
        menu.addItem(item(L10n.menuSettings, #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(item(L10n.menuQuit, #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: - Действия

    @objc private func toggleEnabled() {
        prefs.isEnabled.toggle()
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let mode = QuitMode(rawValue: raw) else { return }
        prefs.mode = mode
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func requestPermission() {
        onRequestPermission?()
    }

    @objc private func quit() {
        Log.app.notice("Quit from the menu")
        NSApp.terminate(nil)
    }
}
