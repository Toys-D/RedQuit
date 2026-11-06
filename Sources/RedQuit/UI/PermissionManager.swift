import AppKit
import ApplicationServices

/// Проверка разрешения «Универсальный доступ».
///
/// Разрешение проверяется по таймеру: как только его выдают в Системных настройках,
/// RedQuit начинает работать без перезапуска. Если разрешение отзывают — останавливается.
@MainActor
final class PermissionManager: ObservableObject {
    @Published private(set) var isTrusted: Bool = AXIsProcessTrusted()

    var onChange: (@MainActor (Bool) -> Void)?

    private var timer: Timer?

    func start() {
        Log.app.notice("Accessibility access: \(self.isTrusted ? "granted" : "not granted", privacy: .public)")
        schedule()
    }

    /// Показывает системный запрос (он же добавляет RedQuit в список Универсального доступа)
    /// и открывает нужный раздел Системных настроек.
    func requestAccess() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openSystemSettings()
    }

    func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func schedule() {
        timer?.invalidate()
        // Пока доступа нет — проверяем каждую секунду, потом — реже, чтобы заметить отзыв.
        let interval: TimeInterval = isTrusted ? 5 : 1
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated { self.check() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func check() {
        let trusted = AXIsProcessTrusted()
        guard trusted != isTrusted else { return }
        isTrusted = trusted
        Log.app.notice("\(trusted ? "Accessibility access granted" : "Accessibility access revoked", privacy: .public)")
        schedule()
        onChange?(trusted)
    }
}
