/// Встроенное исключение: системный процесс, который RedQuit не трогает никогда.
/// `name` — английское название; перевод для интерфейса — в L10n.
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
        .init(bundleID: "com.apple.loginwindow", name: "Login window"),
        .init(bundleID: "com.apple.controlcenter", name: "Control Center"),
        .init(bundleID: "com.apple.notificationcenterui", name: "Notification Center"),
        .init(bundleID: "com.apple.WindowManager", name: "Stage Manager"),
        .init(bundleID: "com.apple.Spotlight", name: "Spotlight"),
        .init(bundleID: "com.apple.SecurityAgent", name: "Password prompts (SecurityAgent)"),
        .init(bundleID: "com.apple.UserNotificationCenter", name: "UserNotificationCenter"),
        .init(bundleID: "com.apple.coreservices.uiagent", name: "CoreServicesUIAgent"),
        .init(bundleID: "com.apple.screencaptureui", name: "Screenshots"),
        .init(bundleID: "com.apple.universalcontrol", name: "Universal Control"),
        .init(bundleID: "com.apple.ScreenSaver.Engine", name: "Screen Saver"),
    ]

    /// Исключения по умолчанию, которые можно удалить из списка.
    public static let defaultUserExclusions: [String] = ["com.apple.finder"]

    private static let builtInLowercased = Set(builtIn.map { $0.bundleID.lowercased() })

    public static func isBuiltIn(_ bundleID: String) -> Bool {
        builtInLowercased.contains(bundleID.lowercased())
    }

    /// Причина (для журнала), по которой программу нельзя трогать, или `nil`, если можно.
    /// Bundle ID сравниваются без учёта регистра.
    public static func reason(bundleID: String?, userExclusions: Set<String>, ownBundleID: String?) -> String? {
        guard let bundleID, !bundleID.isEmpty else { return "the app has no bundle ID" }
        let id = bundleID.lowercased()
        if let own = ownBundleID?.lowercased(), id == own { return "it is RedQuit itself" }
        if builtInLowercased.contains(id) { return "it is a system process" }
        if userExclusions.contains(where: { $0.lowercased() == id }) { return "the app is in the exclusion list" }
        return nil
    }
}
