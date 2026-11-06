/// Итог проверки после закрытия окна. Причина — для журнала (на английском).
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
                return .keep(reason: "a floating panel (\(subrole)) was closed, not a regular window")
            }
            return .quit(reason: "“Any window” mode: a window was closed with the red button")

        case .lastWindow:
            guard let remainingAX else {
                return .keep(reason: "could not read the app’s window list, keeping it to be safe")
            }
            let open = remainingAX.filter(\.countsAsOpen)
            if !open.isEmpty {
                let minimized = open.filter(\.isMinimized).count
                var reason = "windows still open: \(open.count)"
                if minimized > 0 { reason += ", minimized: \(minimized)" }
                return .keep(reason: reason)
            }
            if !otherWindows.isEmpty {
                return .keep(reason: "no windows on this desktop, but the window server sees \(otherWindows.count) more, "
                    + "probably on another desktop or in full screen")
            }
            return .quit(reason: "the last window was closed")
        }
    }
}
