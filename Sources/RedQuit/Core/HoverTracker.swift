import AppKit
import ApplicationServices
import RedQuitCore

/// Запоминает красную кнопку, над которой остановился курсор.
///
/// Зачем: при быстром клике (особенно касанием трекпада) нажатие и отпускание идут почти
/// одновременно, и программа может закрыть окно раньше, чем RedQuit успеет спросить, что
/// было под курсором. Поэтому кнопку находим заранее — когда курсор останавливается
/// у левого верхнего угла окна.
///
/// Чтобы не ошибиться, запомненная кнопка используется, только если её окно исчезло
/// не раньше момента нажатия (за этим следит подписка на уничтожение окна).
@MainActor
final class HoverTracker {
    /// Проверяем, когда курсор не двигался столько времени…
    static let debounce: TimeInterval = 0.035
    /// …или не реже, чем раз в это время при медленном движении.
    static let maxInterval: TimeInterval = 0.15

    @MainActor
    private final class Cached {
        let hit: CloseButtonHit
        let observer: WindowDestroyObserver
        var destroyedAt: TimeInterval?

        init(hit: CloseButtonHit) {
            self.hit = hit
            self.observer = WindowDestroyObserver(pid: hit.pid, window: hit.window)
        }
    }

    private let detector: CloseButtonDetector
    private var lastPoint: CGPoint = .zero
    private var lastMove: TimeInterval = 0
    private var lastCheck: TimeInterval = 0
    private var timer: Timer?
    private var cached: Cached?

    init(detector: CloseButtonDetector) {
        self.detector = detector
    }

    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    func mouseMoved(to point: CGPoint) {
        lastPoint = point
        lastMove = now
        if let cached, !cached.hit.releaseZone.contains(point) {
            clear()
        }
        if timer == nil {
            schedule()
        }
    }

    /// Запомненная кнопка для нажатия в точке `point` в момент `timestamp`
    /// (`NSEvent.timestamp`, отсчитывается от запуска системы, как `systemUptime`).
    func hit(for point: CGPoint, at timestamp: TimeInterval) -> CloseButtonHit? {
        guard let cached, cached.hit.releaseZone.contains(point) else { return nil }
        if let destroyedAt = cached.destroyedAt, destroyedAt < timestamp - 0.01 {
            // Окно исчезло ещё до нажатия (например, закрыто через ⌘W) — нажатие не по нему.
            return nil
        }
        return cached.hit
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        clear()
    }

    // MARK: - Внутреннее

    private func schedule() {
        let timer = Timer(timeInterval: Self.debounce, repeats: false) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated { self.fire() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func fire() {
        timer = nil
        let t = now
        if t - lastMove < Self.debounce, t - lastCheck < Self.maxInterval {
            schedule()
            return
        }
        lastCheck = t
        check(lastPoint)
    }

    private func check(_ point: CGPoint) {
        if let cached, cached.destroyedAt == nil, cached.hit.releaseZone.contains(point) { return }
        // Дешёвая предварительная проверка без запросов к программе: курсор у левого
        // верхнего угла переднего окна? Только тогда спрашиваем AX.
        guard WindowInventory.isNearTrafficLights(point) else { return }
        guard let hit = detector.hitTest(at: point) else { return }
        clear()
        let entry = Cached(hit: hit)
        entry.observer.onDestroyed = { [weak self, weak entry] in
            guard let self, let entry, self.cached === entry else { return }
            entry.destroyedAt = self.now
        }
        cached = entry
        Log.click.debug("Курсор над красной кнопкой «\(hit.appName, privacy: .public)» — запомнили")
    }

    private func clear() {
        cached?.observer.invalidate()
        cached = nil
    }
}
