import AppKit
import ApplicationServices
import RedQuitCore

/// Сбор сведений об окнах программы: через AX и через оконный сервер.
@MainActor
enum WindowInventory {
    /// Окна программы по данным AX (только текущий рабочий стол + свёрнутые),
    /// без окна `closed`. `nil` — AX не ответил.
    static func axWindows(pid: pid_t, excluding closed: AXUIElement?) -> [AXWindowInfo]? {
        let app = AXUIElementCreateApplication(pid)
        let (list, error) = AX.elements(app, kAXWindowsAttribute)
        guard let list else {
            Log.decision.info("Список окон через AX не получен: AXError \(error.rawValue)")
            return nil
        }
        return list.compactMap { window in
            if let closed, CFEqual(window, closed) { return nil }
            return AXWindowInfo(
                subrole: AX.string(window, kAXSubroleAttribute),
                isMinimized: AX.bool(window, kAXMinimizedAttribute) ?? false
            )
        }
    }

    /// Все окна оконного сервера (включая окна на других рабочих столах и спрятанные).
    static func windowRecords(onScreenOnly: Bool = false) -> [CGWindowRecord] {
        let options: CGWindowListOption = onScreenOnly
            ? [.optionOnScreenOnly, .excludeDesktopElements]
            : [.optionAll, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
        return raw.compactMap(CGWindowRecord.init(dictionary:))
    }

    /// Номера окон, которые стоят на каком-либо рабочем столе (видимы там), всех программ.
    /// Окна, которые программа спрятала (закрыла без уничтожения), сюда не попадают.
    static func windowNumbersOnAllSpaces() -> Set<UInt32>? {
        guard let numbers = NSWindow.windowNumbers(options: [.allApplications, .allSpaces]) else { return nil }
        return Set(numbers.map(\.uint32Value))
    }

    /// Курсор у левого верхнего угла переднего обычного окна под ним? Дешёвая проверка
    /// без запросов к самой программе.
    static func isNearTrafficLights(_ point: CGPoint) -> Bool {
        guard let front = windowRecords(onScreenOnly: true).first(where: {
            $0.layer == 0 && $0.alpha > 0.01 && $0.bounds.contains(point)
        }) else { return false }
        return WindowRules.isInTrafficLightZone(point: point, windowBounds: front.bounds)
    }

    /// Номер окна оконного сервера для окна AX — сопоставление по рамке.
    static func windowID(pid: pid_t, frame: CGRect) -> UInt32? {
        WindowRules.matchWindowID(frame: frame, pid: pid, records: windowRecords(onScreenOnly: true))
    }

    /// Окна программы, которых не видно через AX (другие рабочие столы, полноэкранный режим).
    static func otherWindows(pid: pid_t, excluding: Set<UInt32>) -> [CGWindowRecord] {
        WindowRules.otherWindows(
            in: windowRecords(),
            pid: pid,
            visibleOnAnySpace: windowNumbersOnAllSpaces(),
            excluding: excluding
        )
    }
}
