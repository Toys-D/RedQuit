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
    /// Жёлтая и зелёная кнопки окна: у настроек и «О программе» они неактивны.
    let windowButtons: WindowButtons
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
                Log.click.debug("Could not get the element under the cursor: AXError \(error.rawValue), \(elapsedMs, format: .fixed(precision: 1)) ms")
            }
            return nil
        }
        let subrole = AX.string(element, kAXSubroleAttribute)
        guard subrole == kAXCloseButtonSubrole else {
            Log.click.debug("Point (\(point.x, format: .fixed(precision: 0)), \(point.y, format: .fixed(precision: 0))): element under the cursor \(AX.string(element, kAXRoleAttribute) ?? "?", privacy: .public)/\(subrole ?? "-", privacy: .public), \(elapsedMs, format: .fixed(precision: 1)) ms")
            return nil
        }

        Log.click.debug("Close button under the cursor at (\(point.x, format: .fixed(precision: 0)), \(point.y, format: .fixed(precision: 0))), lookup took \(elapsedMs, format: .fixed(precision: 1)) ms")

        guard let pid = AX.pid(element), pid != ProcessInfo.processInfo.processIdentifier,
              let app = NSRunningApplication(processIdentifier: pid)
        else { return nil }
        let appName = app.localizedName ?? app.bundleIdentifier ?? "pid \(pid)"

        if AX.bool(element, kAXEnabledAttribute) == false {
            Log.click.info("\"\(appName, privacy: .public)\": the red button is disabled, skipping")
            return nil
        }

        guard let resolved = resolveWindow(for: element, pid: pid) else {
            Log.click.notice("\"\(appName, privacy: .public)\": red button pressed, but its window could not be found, skipping")
            return nil
        }
        let (window, source) = resolved

        let windowFrame = AX.frame(window)
        let isFullScreen = AX.bool(window, "AXFullScreen") ?? false
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
            windowButtons: buttons(of: window, isFullScreen: isFullScreen),
            windowFrame: windowFrame,
            windowID: windowID,
            isFullScreen: isFullScreen,
            buttonFrame: AX.frame(element),
            clickPoint: point
        )
    }

    private func buttons(of window: AXUIElement, isFullScreen: Bool) -> WindowButtons {
        func enabled(_ attribute: String) -> Bool? {
            AX.element(window, attribute).flatMap { AX.bool($0, kAXEnabledAttribute) }
        }
        return WindowButtons(
            minimizeEnabled: enabled(kAXMinimizeButtonAttribute),
            zoomEnabled: enabled(kAXZoomButtonAttribute),
            fullScreenEnabled: enabled(kAXFullScreenButtonAttribute),
            isFullScreen: isFullScreen
        )
    }

    /// Окно, которому принадлежит кнопка. Обычно это атрибут AXWindow; на случай
    /// нестандартной иерархии — поиск по родителям, в крайнем случае — активное окно программы.
    private func resolveWindow(for button: AXUIElement, pid: pid_t) -> (AXUIElement, String)? {
        if let window = AX.element(button, kAXWindowAttribute),
           AX.string(window, kAXRoleAttribute) == kAXWindowRole {
            return (window, "the AXWindow attribute")
        }
        var current = button
        for _ in 0..<10 {
            guard let parent = AX.element(current, kAXParentAttribute) else { break }
            if AX.string(parent, kAXRoleAttribute) == kAXWindowRole {
                return (parent, "the parent chain")
            }
            current = parent
        }
        let app = AXUIElementCreateApplication(pid)
        if let focused = AX.element(app, kAXFocusedWindowAttribute) {
            return (focused, "the app’s focused window")
        }
        return nil
    }
}
