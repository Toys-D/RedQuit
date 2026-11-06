/// Встроенное исключение: системный процесс, который RedQuit не трогает никогда.
public struct BuiltInExclusion: Sendable, Identifiable {
    public let bundleID: String
    public let name: String
    public var id: String { bundleID }
}

public enum ExclusionRules {
    /// Системные процессы. Их нельзя удалить из исключений.
    public static let builtIn: [BuiltInExclusion] = [
        .init(bundleID: "com.apple.dock", name: "Dock"),
        .init(bundleID: "com.apple.systemuiserver", name: "SystemUIServer"),
        .init(bundleID: "com.apple.loginwindow", name: "Окно входа (loginwindow)"),
        .init(bundleID: "com.apple.controlcenter", name: "Пункт управления"),
        .init(bundleID: "com.apple.notificationcenterui", name: "Центр уведомлений"),
        .init(bundleID: "com.apple.WindowManager", name: "Window Manager (Stage Manager)"),
        .init(bundleID: "com.apple.Spotlight", name: "Spotlight"),
        .init(bundleID: "com.apple.SecurityAgent", name: "SecurityAgent (запросы пароля)"),
        .init(bundleID: "com.apple.UserNotificationCenter", name: "UserNotificationCenter"),
        .init(bundleID: "com.apple.coreservices.uiagent", name: "CoreServicesUIAgent"),
        .init(bundleID: "com.apple.screencaptureui", name: "Снимки экрана"),
        .init(bundleID: "com.apple.universalcontrol", name: "Универсальное управление"),
        .init(bundleID: "com.apple.ScreenSaver.Engine", name: "Заставка"),
    ]

    /// Исключения по умолчанию, которые можно удалить из списка.
    public static let defaultUserExclusions: [String] = ["com.apple.finder"]

    private static let builtInLowercased = Set(builtIn.map { $0.bundleID.lowercased() })

    public static func isBuiltIn(_ bundleID: String) -> Bool {
        builtInLowercased.contains(bundleID.lowercased())
    }

    /// Причина, по которой программу нельзя трогать, или `nil`, если можно.
    /// Bundle ID сравниваются без учёта регистра.
    public static func reason(bundleID: String?, userExclusions: Set<String>, ownBundleID: String?) -> String? {
        guard let bundleID, !bundleID.isEmpty else { return "у программы нет bundle ID" }
        let id = bundleID.lowercased()
        if let own = ownBundleID?.lowercased(), id == own { return "это сам RedQuit" }
        if builtInLowercased.contains(id) { return "системный процесс" }
        if userExclusions.contains(where: { $0.lowercased() == id }) { return "программа в списке исключений" }
        return nil
    }
}
