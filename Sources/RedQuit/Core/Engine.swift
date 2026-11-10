import AppKit
import RedQuitCore

/// Связывает всё вместе: клик → красная кнопка → окно закрылось → решение → завершение.
@MainActor
final class Engine {
    /// Пауза после закрытия окна перед подсчётом оставшихся: даёт программе завершить
    /// анимации и закрыть остальные окна (например, при ⌥-клике по красной кнопке).
    static let settleDelay: Duration = .milliseconds(400)

    private let prefs: Preferences
    private let monitor = ClickMonitor()
    private let detector = CloseButtonDetector()
    private let watcher = WindowCloseWatcher()
    private lazy var hover = HoverTracker(detector: detector)
    private let ownBundleID = Bundle.main.bundleIdentifier
    /// Программы, которым уже отправлен запрос на завершение.
    private var quitting: Set<pid_t> = []

    private(set) var isActive = false

    init(prefs: Preferences) {
        self.prefs = prefs
        monitor.onMouseDown = { [weak self] point, timestamp in self?.mouseDown(at: point, timestamp: timestamp) }
        monitor.onMouseUp = { [weak self] point in self?.watcher.mouseUp(at: point) }
        monitor.onMouseMoved = { [weak self] point in self?.hover.mouseMoved(to: point) }
        watcher.onResult = { [weak self] hit, result in self?.handle(hit, result) }
    }

    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        if active {
            monitor.start()
            Log.app.notice("Watching red buttons (mode: \(self.prefs.mode.logName, privacy: .public))")
        } else {
            monitor.stop()
            hover.reset()
            watcher.cancelAll(reason: "watching stopped")
            Log.app.notice("Stopped watching red buttons")
        }
    }

    // MARK: - Клик

    private func mouseDown(at point: CGPoint, timestamp: TimeInterval) {
        Log.click.debug("Mouse down at (\(point.x, format: .fixed(precision: 0)), \(point.y, format: .fixed(precision: 0)))")
        var found = detector.hitTest(at: point)
        if found == nil, let remembered = hover.hit(for: point, at: timestamp) {
            // Быстрый клик: окно уже закрылось, но курсор перед этим стоял на его красной кнопке.
            Log.click.info("\"\(remembered.appName, privacy: .public)\": the window closed before the check, using the red button found on hover")
            found = remembered
        }
        guard let hit = found else {
            watcher.mouseDownElsewhere()
            return
        }
        if let reason = skipReason(for: hit.app) {
            Log.click.info("\"\(hit.appName, privacy: .public)\": red button, but \(reason, privacy: .public), leaving it alone")
            return
        }
        let fullScreen = hit.isFullScreen ? ", full screen" : ""
        let auxiliary = hit.windowButtons.isAuxiliary ? ", settings-type window" : ""
        Log.click.notice("\"\(hit.appName, privacy: .public)\" [\(hit.bundleID ?? "?", privacy: .public)]: red button pressed (window \(hit.windowSubrole ?? "?", privacy: .public)\(fullScreen, privacy: .public)\(auxiliary, privacy: .public), found via \(hit.windowSource, privacy: .public), id \(hit.windowID.map(String.init) ?? "?", privacy: .public))")
        watcher.mouseDown(on: hit)
    }

    private func skipReason(for app: NSRunningApplication) -> String? {
        if let reason = ExclusionRules.reason(
            bundleID: app.bundleIdentifier,
            userExclusions: prefs.userExclusionSet,
            ownBundleID: ownBundleID
        ) {
            return reason
        }
        if app.activationPolicy != .regular {
            return "it is a background app without a Dock icon"
        }
        return nil
    }

    // MARK: - Окно закрылось или нет

    private func handle(_ hit: CloseButtonHit, _ result: WindowCloseWatcher.Result) {
        switch result {
        case .cancelled(let reason):
            Log.watch.notice("\"\(hit.appName, privacy: .public)\": doing nothing, \(reason, privacy: .public)")
        case .closed(let destroyed, let detail):
            Log.watch.notice("\"\(hit.appName, privacy: .public)\": window closed (\(detail, privacy: .public))")
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: Self.settleDelay)
                self?.decide(hit, windowDestroyed: destroyed)
            }
        }
    }

    // MARK: - Решение

    private func decide(_ hit: CloseButtonHit, windowDestroyed: Bool, attempt: Int = 0) {
        let name = hit.appName
        guard isActive, prefs.isEnabled else {
            Log.decision.notice("\"\(name, privacy: .public)\": RedQuit is paused, doing nothing")
            return
        }
        guard !hit.app.isTerminated else {
            Log.decision.notice("\"\(name, privacy: .public)\": the app has already quit by itself")
            return
        }
        if let reason = skipReason(for: hit.app) {
            Log.decision.notice("\"\(name, privacy: .public)\": \(reason, privacy: .public), leaving it alone")
            return
        }

        let mode = prefs.mode
        var remaining: [AXWindowInfo]?
        var others: [CGWindowRecord] = []

        if mode == .lastWindow {
            remaining = WindowInventory.axWindows(pid: hit.pid, excluding: hit.window)
            if let remaining {
                let details = remaining
                    .map { "\($0.subrole ?? "no subrole")\($0.isMinimized ? " (minimized)" : "")" }
                    .joined(separator: ", ")
                Log.decision.info("\"\(name, privacy: .public)\": windows according to AX: \(remaining.count) [\(details, privacy: .public)]")
            }
            let hasOpen = remaining?.contains(where: \.countsAsOpen) ?? false
            if remaining != nil, !hasOpen {
                // AX видит только текущий рабочий стол — спрашиваем оконный сервер.
                // Уничтоженное окно исключаем на случай, если оконный сервер ещё не успел его убрать.
                let exclude: Set<UInt32> = windowDestroyed ? Set(hit.windowID.map { [$0] } ?? []) : []
                others = WindowInventory.otherWindows(pid: hit.pid, excluding: exclude)
                for record in others {
                    Log.decision.info("\"\(name, privacy: .public)\": the window server sees window id \(record.windowID), \(Int(record.bounds.width))×\(Int(record.bounds.height)), on screen: \(record.isOnscreen)")
                }
            }
        }

        let decision = QuitDecider.decide(
            mode: mode,
            closedWindowSubrole: hit.windowSubrole,
            closedWindowButtons: hit.windowButtons,
            remainingAX: remaining,
            otherWindows: others
        )
        // Окна видит только оконный сервер, а AX — нет. Это может быть настоящее окно на другом
        // рабочем столе, а может быть временное окно анимации (например, выход из полноэкранного
        // режима создаёт окно во весь экран). Временное быстро исчезает — перепроверяем.
        if !decision.shouldQuit, !others.isEmpty, attempt < Self.recheckDelays.count {
            let delay = Self.recheckDelays[attempt]
            Log.decision.info("\"\(name, privacy: .public)\": only the window server sees windows, checking again in \(delay.components.seconds) s")
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: delay)
                self?.decide(hit, windowDestroyed: windowDestroyed, attempt: attempt + 1)
            }
            return
        }

        switch decision {
        case .keep(let reason):
            Log.decision.notice("\"\(name, privacy: .public)\" keeps running: \(reason, privacy: .public)")
        case .quit(let reason):
            terminate(hit, reason: reason)
        }
    }

    /// Паузы перед повторными проверками, когда окна видит только оконный сервер.
    static let recheckDelays: [Duration] = [.seconds(1), .seconds(1)]

    private func terminate(_ hit: CloseButtonHit, reason: String) {
        guard !quitting.contains(hit.pid) else { return }
        quitting.insert(hit.pid)

        // Только штатное завершение — то же, что ⌘Q. Программа сама спросит о несохранённом.
        let sent = hit.app.terminate()
        if sent {
            Log.decision.notice("\"\(hit.appName, privacy: .public)\": quitting normally (like ⌘Q): \(reason, privacy: .public)")
        } else {
            Log.decision.error("\"\(hit.appName, privacy: .public)\": macOS did not accept the quit request")
        }

        let pid = hit.pid
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(10))
            self?.quitting.remove(pid)
        }
    }
}
