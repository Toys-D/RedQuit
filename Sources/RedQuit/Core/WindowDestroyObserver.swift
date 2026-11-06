import ApplicationServices
import Foundation

/// Подписка на уведомление AX «окно уничтожено» для одного окна.
@MainActor
final class WindowDestroyObserver {
    private let window: AXUIElement
    private var observer: AXObserver?

    /// Вызывается один раз, когда окно уничтожено.
    var onDestroyed: (@MainActor () -> Void)?

    /// `false` — подписаться не удалось (окно уже уничтожено или программа не поддерживает
    /// уведомление); тогда остаётся только опрашивать окно.
    private(set) var isActive = false

    init(pid: pid_t, window: AXUIElement) {
        self.window = window
        var created: AXObserver?
        let error = AXObserverCreate(pid, { _, _, notification, refcon in
            guard let refcon else { return }
            let me = Unmanaged<WindowDestroyObserver>.fromOpaque(refcon).takeUnretainedValue()
            let name = notification as String
            MainActor.assumeIsolated {
                if name == kAXUIElementDestroyedNotification {
                    me.onDestroyed?()
                }
            }
        }, &created)
        guard error == .success, let created else {
            Log.watch.debug("AXObserver не создан (AXError \(error.rawValue))")
            return
        }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let addError = AXObserverAddNotification(created, window, kAXUIElementDestroyedNotification as CFString, refcon)
        guard addError == .success else {
            Log.watch.debug("Подписка на уничтожение окна не удалась (AXError \(addError.rawValue))")
            return
        }
        // Общие режимы цикла: уведомление придёт, даже пока открыто меню RedQuit.
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observer = created
        isActive = true
    }

    func invalidate() {
        if let observer {
            AXObserverRemoveNotification(observer, window, kAXUIElementDestroyedNotification as CFString)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        isActive = false
        onDestroyed = nil
    }
}
