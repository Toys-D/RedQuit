import Foundation
import RedQuitCore

/// Настройки RedQuit (хранятся в UserDefaults).
@MainActor
final class Preferences: ObservableObject {
    private enum Key {
        static let enabled = "enabled"
        static let mode = "mode"
        static let userExclusions = "userExclusions"
    }

    private let defaults = UserDefaults.standard

    /// Вызывается после любого изменения настроек.
    var onChange: (@MainActor () -> Void)?

    @Published var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            defaults.set(isEnabled, forKey: Key.enabled)
            Log.app.notice("\(self.isEnabled ? "Resumed" : "Paused", privacy: .public)")
            onChange?()
        }
    }

    @Published var mode: QuitMode {
        didSet {
            guard mode != oldValue else { return }
            defaults.set(mode.rawValue, forKey: Key.mode)
            Log.app.notice("Mode: \(self.mode.logName, privacy: .public)")
            onChange?()
        }
    }

    /// Исключения, которые можно удалить (bundle ID). Встроенные — в `ExclusionRules.builtIn`.
    @Published private(set) var userExclusions: [String] {
        didSet {
            defaults.set(userExclusions, forKey: Key.userExclusions)
            onChange?()
        }
    }

    init() {
        defaults.register(defaults: [
            Key.enabled: true,
            Key.mode: QuitMode.lastWindow.rawValue,
            Key.userExclusions: ExclusionRules.defaultUserExclusions,
        ])
        _isEnabled = Published(initialValue: defaults.bool(forKey: Key.enabled))
        _mode = Published(initialValue: QuitMode(rawValue: defaults.string(forKey: Key.mode) ?? "") ?? .lastWindow)
        _userExclusions = Published(initialValue: defaults.stringArray(forKey: Key.userExclusions)
            ?? ExclusionRules.defaultUserExclusions)
    }

    var userExclusionSet: Set<String> { Set(userExclusions) }

    /// Добавляет исключение. Возвращает `false`, если оно уже есть (в т. ч. среди встроенных).
    @discardableResult
    func addExclusion(_ bundleID: String) -> Bool {
        let lower = bundleID.lowercased()
        guard !ExclusionRules.isBuiltIn(bundleID),
              lower != Bundle.main.bundleIdentifier?.lowercased(),
              !userExclusions.contains(where: { $0.lowercased() == lower })
        else { return false }
        userExclusions.append(bundleID)
        Log.app.notice("Exclusion added: \(bundleID, privacy: .public)")
        return true
    }

    func removeExclusion(_ bundleID: String) {
        userExclusions.removeAll { $0 == bundleID }
        Log.app.notice("Exclusion removed: \(bundleID, privacy: .public)")
    }
}
