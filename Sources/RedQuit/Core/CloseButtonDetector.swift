import AppKit
import ApplicationServices
import RedQuitCore

/// Нажатая красная кнопка и всё, что о ней известно в момент нажатия.
struct CloseButtonHit {
    let pid: pid_t
    let app: NSRunningApplication
    let appName: String
    let bundleID: String?
    let button: AXUIElement
    let window: AXUIElement
    /// Как найдено окно (для журнала).
    let windowSource: String
    let windowSubrole: String?
    let windowFrame: CGRect?
    /// Номер окна в оконном сервере, если удалось сопоставить по рамке.
    let windowID: UInt32?
    let isFullScreen: Bool
    let buttonFrame: CGRect?
    let clickPoint: CGPoint

    /// Где отпускание кнопки мыши означает «нажатие засчитано». Небольшой запас —
    /// на случай округлений.
    var releaseZone: CGRect {
        let base = buttonFrame ?? CGRect(origin: clickPoint, size: .zero).insetBy(dx: -6, dy: -6)
        return base.insetBy(dx: -3, dy: -3)
    }
}

/// Определяет, нажата ли красная кнопка закрытия окна.
@MainActor
final class CloseButtonDetector {
    private let systemWide = AXUIElementCreateSystemWide()

    init() {
        // Таймаут для запросов AX. Для системного элемента он действует глобально:
        // зависшая программа не подвесит RedQuit дольше чем на 0,5 с.
        AXUIElementSetMessagingTimeout(systemWide, 0.5)
    }

    func hitTest(at point: CGPoint) -> CloseButtonHit? {
        let started = DispatchTime.now().uptimeNanoseconds
        var found: AXUIElement?
        let error = AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &found)
        let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000

        guard error == .success, let element = found else {
            if error != .noValue {
                Log.click.debug("Не удалось узнать элемент под курсором: AXError \(error.rawValue), \(elapsedMs, format: .fixed(precision: 1)) мс")
            }
            return nil
        }
        guard AX.string(element, kAXSubroleAttribute) == kAXCloseButtonSubrole else { return nil }

        Log.click.debug("Под курсором кнопка закрытия (\(point.x, format: .fixed(precision: 0)), \(point.y, format: .fixed(precision: 0))), поиск занял \(elapsedMs, format: .fixed(precision: 1)) мс")

        guard let pid = AX.pid(element), pid != ProcessInfo.processInfo.processIdentifier,
              let app = NSRunningApplication(processIdentifier: pid)
        else { return nil }
        let appName = app.localizedName ?? app.bundleIdentifier ?? "pid \(pid)"

        if AX.bool(element, kAXEnabledAttribute) == false {
            Log.click.info("«\(appName, privacy: .public)»: красная кнопка неактивна — пропускаем")
            return nil
        }

        guard let resolved = resolveWindow(for: element, pid: pid) else {
            Log.click.notice("«\(appName, privacy: .public)»: нажата красная кнопка, но не удалось определить её окно — пропускаем")
            return nil
        }
        let (window, source) = resolved

        let windowFrame = AX.frame(window)
        let windowID = windowFrame.flatMap { WindowInventory.windowID(pid: pid, frame: $0) }

        return CloseButtonHit(
            pid: pid,
            app: app,
            appName: appName,
            bundleID: app.bundleIdentifier,
            button: element,
            window: window,
            windowSource: source,
            windowSubrole: AX.string(window, kAXSubroleAttribute),
            windowFrame: windowFrame,
            windowID: windowID,
            isFullScreen: AX.bool(window, "AXFullScreen") ?? false,
            buttonFrame: AX.frame(element),
            clickPoint: point
        )
    }

    /// Окно, которому принадлежит кнопка. Обычно это атрибут AXWindow; на случай
    /// нестандартной иерархии — поиск по родителям, в крайнем случае — активное окно программы.
    private func resolveWindow(for button: AXUIElement, pid: pid_t) -> (AXUIElement, String)? {
        if let window = AX.element(button, kAXWindowAttribute),
           AX.string(window, kAXRoleAttribute) == kAXWindowRole {
            return (window, "атрибут AXWindow")
        }
        var current = button
        for _ in 0..<10 {
            guard let parent = AX.element(current, kAXParentAttribute) else { break }
            if AX.string(parent, kAXRoleAttribute) == kAXWindowRole {
                return (parent, "поиск по родителям")
            }
            current = parent
        }
        let app = AXUIElementCreateApplication(pid)
        if let focused = AX.element(app, kAXFocusedWindowAttribute) {
            return (focused, "активное окно программы")
        }
        return nil
    }
}
