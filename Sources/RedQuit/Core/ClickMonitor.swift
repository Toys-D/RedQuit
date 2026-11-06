import AppKit
import RedQuitCore

/// Слушает мышь во всей системе: нажатие и отпускание левой кнопки, движение курсора.
///
/// Используется глобальный монитор NSEvent: он получает только КОПИИ событий, уже
/// доставленных другим программам, и по своей природе не может задержать, изменить
/// или отменить событие.
@MainActor
final class ClickMonitor {
    /// Точка — в глобальных координатах Quartz/AX (начало — левый верхний угол основного
    /// экрана); время — `NSEvent.timestamp` (секунды от запуска системы).
    var onMouseDown: (@MainActor (CGPoint, TimeInterval) -> Void)?
    var onMouseUp: (@MainActor (CGPoint) -> Void)?
    var onMouseMoved: (@MainActor (CGPoint) -> Void)?

    private var token: Any?

    var isRunning: Bool { token != nil }

    func start() {
        guard token == nil else { return }
        token = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp, .mouseMoved]) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self else { return }
                let point = Self.quartzLocation(of: event)
                switch event.type {
                case .leftMouseDown: self.onMouseDown?(point, event.timestamp)
                case .leftMouseUp: self.onMouseUp?(point)
                case .mouseMoved: self.onMouseMoved?(point)
                default: break
                }
            }
        }
        if token == nil {
            Log.app.error("Не удалось установить глобальный монитор мыши")
        }
    }

    func stop() {
        if let token { NSEvent.removeMonitor(token) }
        token = nil
    }

    /// Координаты события в системе AX.
    ///
    /// `CGEvent.location` уже в глобальных координатах Quartz — те же, что у AX, для всех
    /// мониторов. Запасной путь — пересчёт из координат AppKit (для глобальных событий
    /// `locationInWindow` — это координаты экрана с началом внизу слева).
    private static func quartzLocation(of event: NSEvent) -> CGPoint {
        if let cgEvent = event.cgEvent {
            return cgEvent.location
        }
        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? 0
        let appKitPoint = event.window == nil ? event.locationInWindow : NSEvent.mouseLocation
        return Coordinates.quartzPoint(fromAppKit: appKitPoint, primaryScreenHeight: primaryHeight)
    }
}
