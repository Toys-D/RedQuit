/// Режим работы RedQuit.
public enum QuitMode: String, CaseIterable, Identifiable, Sendable {
    /// Программа завершается, когда красной кнопкой закрыто её последнее окно.
    case lastWindow
    /// Программа завершается при закрытии красной кнопкой любого её окна.
    case anyWindow

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .lastWindow: "Последнее окно"
        case .anyWindow: "Любое окно"
        }
    }

    public var explanation: String {
        switch self {
        case .lastWindow: "Программа завершается, когда красной кнопкой закрыто её последнее окно."
        case .anyWindow: "Программа завершается при закрытии красной кнопкой любого её окна."
        }
    }
}
