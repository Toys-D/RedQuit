/// Режим работы RedQuit. Названия для интерфейса — в L10n (модуль приложения).
public enum QuitMode: String, CaseIterable, Identifiable, Sendable {
    /// Программа завершается, когда красной кнопкой закрыто её последнее окно.
    case lastWindow
    /// Программа завершается при закрытии красной кнопкой любого её окна.
    case anyWindow

    public var id: String { rawValue }

    /// Название для журнала (журнал ведётся на английском).
    public var logName: String {
        switch self {
        case .lastWindow: "Last window"
        case .anyWindow: "Any window"
        }
    }
}
