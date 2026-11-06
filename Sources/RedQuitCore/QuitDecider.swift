/// Итог проверки после закрытия окна.
public enum QuitDecision: Equatable, Sendable {
    case quit(reason: String)
    case keep(reason: String)

    public var shouldQuit: Bool {
        if case .quit = self { return true }
        return false
    }

    public var reason: String {
        switch self {
        case .quit(let r), .keep(let r): r
        }
    }
}

/// Решение «завершать или нет». Вызывается, когда окно уже точно закрыто красной кнопкой.
/// Принцип: при любом сомнении программу не завершаем.
public enum QuitDecider {
    /// - Parameters:
    ///   - closedWindowSubrole: AXSubrole закрытого окна.
    ///   - remainingAX: оставшиеся окна программы по данным AX (без закрытого);
    ///     `nil` — AX не ответил.
    ///   - otherWindows: окна, которые видит оконный сервер, но не видит AX
    ///     (другие рабочие столы, полноэкранный режим). Нужны только для «Последнего окна».
    public static func decide(
        mode: QuitMode,
        closedWindowSubrole: String?,
        remainingAX: [AXWindowInfo]?,
        otherWindows: [CGWindowRecord]
    ) -> QuitDecision {
        switch mode {
        case .anyWindow:
            if let subrole = closedWindowSubrole, WindowSubrole.floatingPanels.contains(subrole) {
                return .keep(reason: "закрыта плавающая панель (\(subrole)), а не обычное окно")
            }
            return .quit(reason: "режим «Любое окно»: окно закрыто красной кнопкой")

        case .lastWindow:
            guard let remainingAX else {
                return .keep(reason: "не удалось получить список окон программы — на всякий случай не завершаем")
            }
            let open = remainingAX.filter(\.countsAsOpen)
            if !open.isEmpty {
                let minimized = open.filter(\.isMinimized).count
                var reason = "осталось окон: \(open.count)"
                if minimized > 0 { reason += ", из них свёрнутых: \(minimized)" }
                return .keep(reason: reason)
            }
            if !otherWindows.isEmpty {
                return .keep(reason: "на этом рабочем столе окон нет, но система видит ещё окон: \(otherWindows.count) — "
                    + "вероятно, на другом рабочем столе или в полноэкранном режиме")
            }
            return .quit(reason: "закрыто последнее окно")
        }
    }
}
