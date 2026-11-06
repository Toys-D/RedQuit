import Foundation
import os

/// Журнал RedQuit. Смотреть в Console.app: фильтр «subsystem:com.toysforminds.RedQuit»,
/// или в терминале: log stream --predicate 'subsystem == "com.toysforminds.RedQuit"' --level info
///
/// Решения пишутся с уровнем notice — они видны и сохраняются без включения отладки.
/// Подробности для калибровки — info/debug.
enum Log {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.toysforminds.RedQuit"

    /// Запуск, разрешения, настройки.
    static let app = Logger(subsystem: subsystem, category: "app")
    /// Клики и поиск красной кнопки.
    static let click = Logger(subsystem: subsystem, category: "click")
    /// Ожидание закрытия окна.
    static let watch = Logger(subsystem: subsystem, category: "watch")
    /// Подсчёт оставшихся окон и завершение программы.
    static let decision = Logger(subsystem: subsystem, category: "decision")
}
