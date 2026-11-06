import AppKit
import ApplicationServices
import RedQuitCore

/// Следит, действительно ли окно закрылось после нажатия красной кнопки.
///
/// Порядок:
/// 1. Нажатие на красную кнопку — сразу подписываемся на уничтожение окна (AXObserver),
///    чтобы не пропустить уведомление.
/// 2. Кнопку мыши отпустили вне красной кнопки — закрытие отменено, забываем.
/// 3. Отпустили на кнопке — ждём: уведомление об уничтожении окна или исчезновение окна
///    из списка окон программы (опрос — для программ, которые прячут окно вместо уничтожения).
/// 4. Если программа показала диалог «Сохранить изменения?», ждём, пока он открыт.
///    Диалог закрылся, а окно осталось — значит, нажали «Отмена»: ничего не делаем.
@MainActor
final class WindowCloseWatcher {
    enum Result {
        /// Окно закрылось. `destroyed` — окно уничтожено (а не спрятано программой).
        case closed(destroyed: Bool, detail: String)
        case cancelled(String)
    }

    enum Timing {
        /// Как часто проверять окно.
        static let poll: TimeInterval = 0.15
        /// Сколько ждать закрытия, если программа не показала диалог.
        static let closeWait: TimeInterval = 2
        /// Сколько ждать, если программа не отвечает на запросы AX (занята).
        static let busyWait: TimeInterval = 10
        /// Сколько максимум ждать решения в диалоге «Сохранить?».
        static let dialogWait: TimeInterval = 600
        /// Сколько ждать закрытия окна после исчезновения диалога («Не сохранять» → окно закрывается).
        static let dialogGrace: TimeInterval = 1
    }

    var onResult: (@MainActor (CloseButtonHit, Result) -> Void)?

    /// Нажатие, для которого ещё не было отпускания.
    private var pressed: CloseWatch?
    /// Нажатия, засчитанные как клик по красной кнопке: ждём закрытия окна.
    private var waiting: [ObjectIdentifier: CloseWatch] = [:]

    func mouseDown(on hit: CloseButtonHit) {
        if let old = pressed {
            finish(old, .cancelled("a new press came before the previous one was released"))
        }
        let watch = CloseWatch(hit: hit)
        watch.startObserving { [weak self, weak watch] in
            guard let self, let watch else { return }
            self.windowDestroyed(watch)
        }
        pressed = watch
    }

    /// Нажатие пришлось не на красную кнопку.
    func mouseDownElsewhere() {
        if let old = pressed {
            finish(old, .cancelled("the release of the previous press was not received"))
        }
    }

    func mouseUp(at point: CGPoint) {
        guard let watch = pressed else { return }
        pressed = nil
        guard watch.hit.releaseZone.contains(point) else {
            finish(watch, .cancelled("the mouse button was released outside the red button, closing was cancelled"))
            return
        }
        if watch.destroyedWhilePressed {
            // Быстрый клик: уведомление об уничтожении окна пришло раньше события отпускания.
            finish(watch, .closed(destroyed: true, detail: "the window closed right after the click"))
            return
        }
        Log.watch.info("\"\(watch.hit.appName, privacy: .public)\": released on the red button, waiting for the window to close")
        waiting[ObjectIdentifier(watch)] = watch
        watch.arm()
        watch.startPolling { [weak self, weak watch] in
            guard let self, let watch else { return }
            self.tick(watch)
        }
    }

    func cancelAll(reason: String) {
        if let pressed { finish(pressed, .cancelled(reason)) }
        for watch in Array(waiting.values) { finish(watch, .cancelled(reason)) }
    }

    // MARK: - Внутреннее

    private func windowDestroyed(_ watch: CloseWatch) {
        if watch === pressed {
            // Отпускание ещё не обработано. Решим, когда оно придёт: если кнопку отпустили
            // на красной кнопке — окно закрыто кликом, иначе — чем-то другим.
            watch.destroyedWhilePressed = true
            return
        }
        guard waiting[ObjectIdentifier(watch)] != nil else { return }
        finish(watch, .closed(destroyed: true, detail: "AX notification: window destroyed"))
    }

    private func tick(_ watch: CloseWatch) {
        guard waiting[ObjectIdentifier(watch)] != nil else { return }
        let name = watch.hit.appName

        if watch.hit.app.isTerminated {
            finish(watch, .cancelled("the app quit by itself"))
            return
        }

        let now = Date()
        switch watch.probe() {
        case .destroyed:
            finish(watch, .closed(destroyed: true, detail: "the window no longer exists"))
            return
        case .hidden:
            finish(watch, .closed(destroyed: false, detail: "the app took the window off screen"))
            return
        case .present(let hasDialog):
            if hasDialog {
                if watch.dialogSeenAt == nil {
                    Log.watch.notice("\"\(name, privacy: .public)\": the app is showing a dialog, waiting for your choice")
                    watch.dialogSeenAt = now
                }
                watch.dialogGoneAt = nil
            } else if watch.dialogSeenAt != nil {
                if let gone = watch.dialogGoneAt {
                    if now.timeIntervalSince(gone) > Timing.dialogGrace {
                        finish(watch, .cancelled("the dialog closed but the window stayed, looks like Cancel was pressed"))
                        return
                    }
                } else {
                    watch.dialogGoneAt = now
                }
            }
        case .elsewhere:
            break
        case .unresponsive:
            if !watch.sawBusy {
                Log.watch.info("\"\(name, privacy: .public)\": the app is not answering AX requests, waiting longer")
            }
            watch.sawBusy = true
        }

        let limit: TimeInterval
        let reason: String
        if watch.dialogSeenAt != nil {
            limit = Timing.dialogWait
            reason = "the dialog has been open for more than \(Int(limit / 60)) minutes, giving up"
        } else if watch.sawBusy {
            limit = Timing.busyWait
            reason = "the window did not close within \(Int(limit)) s and the app is not responding"
        } else {
            limit = Timing.closeWait
            reason = "the window did not close within \(Int(limit)) s, the app apparently kept it open"
        }
        if watch.elapsedSinceArm > limit {
            finish(watch, .cancelled(reason))
        }
    }

    private func finish(_ watch: CloseWatch, _ result: Result) {
        watch.stop()
        waiting[ObjectIdentifier(watch)] = nil
        if pressed === watch { pressed = nil }
        onResult?(watch.hit, result)
    }
}

/// Одно наблюдение за окном.
@MainActor
final class CloseWatch {
    enum Probe {
        /// Окно уничтожено.
        case destroyed
        /// Окно существует, но программа убрала его с экрана (закрыла без уничтожения).
        case hidden
        /// Окно на месте; `hasDialog` — к нему прикреплён лист или появился диалог.
        case present(hasDialog: Bool)
        /// Окно пропало из списка AX, но оконный сервер видит его на другом рабочем столе.
        case elsewhere
        /// Программа не ответила на запрос AX.
        case unresponsive
    }

    let hit: CloseButtonHit
    var dialogSeenAt: Date?
    var dialogGoneAt: Date?
    var sawBusy = false
    var destroyedWhilePressed = false

    private var armedAt: Date?
    private var observer: WindowDestroyObserver?
    private var timer: Timer?
    private var preexistingDialogs: [AXUIElement] = []

    init(hit: CloseButtonHit) {
        self.hit = hit
    }

    var elapsedSinceArm: TimeInterval {
        armedAt.map { Date().timeIntervalSince($0) } ?? 0
    }

    /// Подписка на уведомление «окно уничтожено». Если подписаться не удалось, закрытие
    /// всё равно заметит опрос окна.
    func startObserving(onDestroyed: @escaping @MainActor () -> Void) {
        let observer = WindowDestroyObserver(pid: hit.pid, window: hit.window)
        observer.onDestroyed = onDestroyed
        if !observer.isActive {
            Log.watch.info("\"\(self.hit.appName, privacy: .public)\": window-close notifications are unavailable, polling the window instead")
        }
        self.observer = observer
    }

    /// Нажатие засчитано: запоминаем время и уже открытые диалоги программы.
    func arm() {
        armedAt = Date()
        let app = AXUIElementCreateApplication(hit.pid)
        preexistingDialogs = (AX.elements(app, kAXWindowsAttribute).list ?? []).filter {
            WindowSubrole.dialogs.contains(AX.string($0, kAXSubroleAttribute) ?? "")
        }
    }

    func startPolling(_ handler: @escaping @MainActor @Sendable () -> Void) {
        let timer = Timer(timeInterval: WindowCloseWatcher.Timing.poll, repeats: true) { _ in
            MainActor.assumeIsolated { handler() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        observer?.invalidate()
        observer = nil
    }

    func probe() -> Probe {
        switch AX.value(hit.window, kAXRoleAttribute).error {
        case .success: break
        case .invalidUIElement: return .destroyed
        case .cannotComplete: return .unresponsive
        default: return .elsewhere
        }

        let app = AXUIElementCreateApplication(hit.pid)
        let (windows, listError) = AX.elements(app, kAXWindowsAttribute)
        guard let windows else {
            return listError == .cannotComplete ? .unresponsive : .elsewhere
        }

        if !windows.contains(where: { CFEqual($0, hit.window) }) {
            // Окна нет среди окон текущего рабочего стола. Если оконный сервер всё ещё видит
            // его на каком-то рабочем столе — окно не закрыто (например, переключили рабочий стол).
            if let id = hit.windowID, let visible = WindowInventory.windowNumbersOnAllSpaces(), visible.contains(id) {
                return .elsewhere
            }
            return .hidden
        }

        let children = AX.elements(hit.window, kAXChildrenAttribute).list ?? []
        let hasSheet = children.contains { AX.string($0, kAXRoleAttribute) == kAXSheetRole }
        let hasNewDialog = windows.contains { window in
            !CFEqual(window, hit.window)
                && WindowSubrole.dialogs.contains(AX.string(window, kAXSubroleAttribute) ?? "")
                && !preexistingDialogs.contains { CFEqual($0, window) }
        }
        return .present(hasDialog: hasSheet || hasNewDialog)
    }
}
