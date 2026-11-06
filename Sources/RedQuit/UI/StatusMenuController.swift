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
        if !permissions.isTrusted { return "RedQuit: нужен доступ к Универсальному доступу" }
        if !prefs.isEnabled { return "RedQuit на паузе" }
        return "RedQuit работает — «\(prefs.mode.title)»"
    }

    /// Обновляет значок: работает / пауза / нет доступа.
    func update() {
        let symbol: String
        if !permissions.isTrusted {
            symbol = "exclamationmark.triangle"
        } else if !prefs.isEnabled {
            symbol = "pause.circle"
        } else {
            symbol = "xmark.circle"
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: statusText)
        image?.isTemplate = true
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
            menu.addItem(item("Выдать доступ…", #selector(requestPermission)))
        }

        menu.addItem(.separator())
        menu.addItem(item(prefs.isEnabled ? "Пауза" : "Включить", #selector(toggleEnabled)))

        let modeItem = NSMenuItem(title: "Режим", action: nil, keyEquivalent: "")
        let modeMenu = NSMenu()
        modeMenu.autoenablesItems = false
        for mode in QuitMode.allCases {
            let modeChoice = item(mode.title, #selector(selectMode(_:)))
            modeChoice.representedObject = mode.rawValue
            modeChoice.state = prefs.mode == mode ? .on : .off
            modeChoice.toolTip = mode.explanation
            modeMenu.addItem(modeChoice)
        }
        modeItem.submenu = modeMenu
        menu.addItem(modeItem)

        menu.addItem(.separator())
        menu.addItem(item("Настройки…", #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(item("Выход", #selector(quit), key: "q"))
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
        Log.app.notice("Выход по команде из меню")
        NSApp.terminate(nil)
    }
}
