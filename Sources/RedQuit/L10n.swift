import Foundation
import RedQuitCore

/// Все строки интерфейса. Ключи — смысловые, английский текст — запасной вариант на случай,
/// если в переводе ключа нет. Переводы: Resources/Localization/<язык>.lproj/Localizable.strings.
/// Тест LocalizationTests проверяет, что во всех языках одинаковые ключи и подстановки.
enum L10n {
    private static func tr(_ key: String, _ english: String) -> String {
        Bundle.main.localizedString(forKey: key, value: english, table: nil)
    }

    private static func format(_ key: String, _ english: String, _ arguments: CVarArg...) -> String {
        String(format: tr(key, english), locale: Locale.current, arguments: arguments)
    }

    // MARK: - Режимы

    static func modeTitle(_ mode: QuitMode) -> String {
        switch mode {
        case .lastWindow: tr("mode.lastWindow.title", "Last window")
        case .anyWindow: tr("mode.anyWindow.title", "Any window")
        }
    }

    static func modeExplanation(_ mode: QuitMode) -> String {
        switch mode {
        case .lastWindow: tr("mode.lastWindow.explanation", "An app quits when its last window is closed with the red button.")
        case .anyWindow: tr("mode.anyWindow.explanation", "An app quits when any of its windows is closed with the red button.")
        }
    }

    // MARK: - Меню в строке меню

    static var statusNeedsAccess: String { tr("menu.status.needsAccess", "RedQuit needs Accessibility access") }
    static var statusPaused: String { tr("menu.status.paused", "RedQuit is paused") }
    static func statusOn(_ modeTitle: String) -> String { format("menu.status.on", "RedQuit is on: %@", modeTitle) }
    static var menuGrantAccess: String { tr("menu.grantAccess", "Grant Access…") }
    static var menuPause: String { tr("menu.pause", "Pause") }
    static var menuResume: String { tr("menu.resume", "Resume") }
    static var menuMode: String { tr("menu.mode", "Mode") }
    static var menuSettings: String { tr("menu.settings", "Settings…") }
    static var menuQuit: String { tr("menu.quit", "Quit RedQuit") }

    // MARK: - Заголовки окон

    static var settingsWindowTitle: String { tr("window.settings.title", "RedQuit Settings") }
    static var permissionWindowTitle: String { tr("window.permission.title", "RedQuit: Accessibility") }

    // MARK: - Окно разрешения

    static var permissionHeading: String { tr("permission.heading", "RedQuit needs Accessibility access") }
    static var permissionBody: String {
        tr("permission.body", "Without it, RedQuit can’t tell that you clicked the red close button or check which windows an app still has open. RedQuit only reads information about windows: it never clicks anything for you and never blocks or changes your clicks.")
    }
    static var permissionStep1: String { tr("permission.step1", "1. Click “Open System Settings”.") }
    static var permissionStep2: String { tr("permission.step2", "2. In Accessibility, turn on the switch next to RedQuit.") }
    static var permissionStep3: String { tr("permission.step3", "3. That’s it. RedQuit starts working on its own, no restart needed.") }
    static var permissionAfterUpdate: String {
        tr("permission.afterUpdate", "The switch is already on but RedQuit still asks? This happens after an update: select RedQuit in the list, remove it with the “−” button and turn it on again.")
    }
    static var permissionGranted: String { tr("permission.granted", "Access granted. RedQuit is working.") }
    static var permissionWaiting: String { tr("permission.waiting", "Waiting for you to turn on access…") }
    static var permissionOpenSettings: String { tr("permission.openSettings", "Open System Settings") }
    static var permissionLater: String { tr("permission.later", "Later") }
    static var permissionDone: String { tr("permission.done", "Done") }

    // MARK: - Настройки

    static var sectionGeneral: String { tr("settings.section.general", "General") }
    static var settingsEnabled: String { tr("settings.enabled", "RedQuit is on") }
    static var settingsMode: String { tr("settings.mode", "Mode") }

    static var sectionStartup: String { tr("settings.section.startup", "Startup") }
    static var settingsOpenAtLogin: String { tr("settings.openAtLogin", "Open at login") }
    static var settingsLoginNeedsApproval: String { tr("settings.loginNeedsApproval", "macOS is waiting for your approval in Login Items.") }
    static var settingsOpen: String { tr("settings.open", "Open") }
    static var settingsNotInApplications: String {
        tr("settings.notInApplications", "RedQuit isn’t running from the Applications folder. Move it there before turning on Open at login.")
    }
    static func settingsLoginError(_ message: String) -> String {
        format("settings.loginError", "Couldn’t change Open at login: %@", message)
    }

    static var sectionAccess: String { tr("settings.section.access", "Access") }
    static var settingsAccessGranted: String { tr("settings.accessGranted", "Accessibility access is on") }
    static var settingsAccessMissing: String { tr("settings.accessMissing", "No Accessibility access") }

    static var sectionExclusions: String { tr("settings.section.exclusions", "Exclusions") }
    static var exclusionsEmpty: String { tr("settings.exclusions.empty", "The list is empty") }
    static var exclusionsAdd: String { tr("settings.exclusions.add", "Add App…") }
    static func exclusionsBuiltIn(_ count: Int) -> String { format("settings.exclusions.builtIn", "Built-in exclusions (%ld)", count) }
    static var exclusionsThisApp: String { tr("settings.exclusions.thisApp", "RedQuit (this app)") }
    static var exclusionsFooter: String {
        tr("settings.exclusions.footer", "RedQuit leaves these apps alone. Background apps without a Dock icon (agents, menu bar utilities) are never touched.")
    }
    static var exclusionsBuiltInHelp: String { tr("settings.exclusions.builtInHelp", "Built-in exclusion, can’t be removed") }
    static var exclusionsRemoveHelp: String { tr("settings.exclusions.removeHelp", "Remove from exclusions") }
    static var exclusionsPanelTitle: String { tr("settings.exclusions.panelTitle", "Choose apps RedQuit should leave alone") }
    static var exclusionsPanelPrompt: String { tr("settings.exclusions.panelPrompt", "Add") }
    static func exclusionsAdded(_ names: String) -> String { format("settings.exclusions.added", "Added: %@", names) }
    static func exclusionsSkipped(_ names: String) -> String { format("settings.exclusions.skipped", "Skipped: %@", names) }
    static func exclusionsNoBundleID(_ name: String) -> String { format("settings.exclusions.noBundleID", "%@ (no bundle ID)", name) }
    static func exclusionsAlreadyListed(_ name: String) -> String { format("settings.exclusions.alreadyListed", "%@ (already in the list)", name) }

    static var sectionLog: String { tr("settings.section.log", "Log") }
    static func logHint(_ subsystem: String) -> String {
        format("settings.log.hint", "To see what RedQuit did and why, open Console and search for “subsystem:%@”.", subsystem)
    }

    static var sectionAbout: String { tr("settings.section.about", "About") }
    static func aboutVersion(_ version: String) -> String { format("settings.about.version", "Version %@", version) }
    static var aboutWebsite: String { tr("settings.about.website", "Website") }

    // MARK: - Встроенные исключения

    /// Описательные названия переводятся; собственные имена (Dock, Spotlight…) остаются как есть.
    static func builtInName(_ item: BuiltInExclusion) -> String {
        tr("builtin." + item.bundleID, item.name)
    }
}
