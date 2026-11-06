import CoreGraphics

/// Правила отбора окон из списка оконного сервера.
///
/// Зачем это нужно: Accessibility API (`kAXWindowsAttribute`) показывает только окна
/// текущего рабочего стола (Space). Окна на других рабочих столах и в чужом полноэкранном
/// пространстве ему не видны. Оконный сервер видит все окна, но среди них много служебных
/// и спрятанных. Отбираем те, что похожи на настоящие окна программы.
public enum WindowRules {
    /// Окна меньше этого размера считаем служебными.
    public static let minimumSize = CGSize(width: 80, height: 40)

    /// Окна программы `pid`, которые выглядят как обычные открытые окна.
    ///
    /// - Parameters:
    ///   - visibleOnAnySpace: номера окон, которые стоят на каком-либо рабочем столе
    ///     (`NSWindow.windowNumbers(options: [.allApplications, .allSpaces])`). Это отсекает
    ///     окна, которые программа закрыла, но не уничтожила (спрятала). `nil` — список
    ///     недоступен: тогда не фильтруем по нему, чтобы не ошибиться в сторону завершения.
    ///   - excluding: номера окон, которые не учитывать (только что закрытое окно).
    public static func otherWindows(
        in records: [CGWindowRecord],
        pid: Int32,
        visibleOnAnySpace: Set<UInt32>?,
        excluding: Set<UInt32>
    ) -> [CGWindowRecord] {
        records.filter { r in
            r.ownerPID == pid
                && r.layer == 0
                && r.alpha > 0.01
                && r.bounds.width >= minimumSize.width
                && r.bounds.height >= minimumSize.height
                && !excluding.contains(r.windowID)
                && (visibleOnAnySpace?.contains(r.windowID) ?? true)
        }
    }

    /// Область кнопок «светофора» от левого верхнего угла окна — с запасом: в окнах
    /// с панелью инструментов кнопки сдвинуты вправо и вниз.
    public static let trafficLightZone = CGSize(width: 64, height: 64)

    /// Находится ли точка там, где у окна могут быть красная, жёлтая и зелёная кнопки.
    public static func isInTrafficLightZone(point: CGPoint, windowBounds: CGRect) -> Bool {
        let dx = point.x - windowBounds.minX
        let dy = point.y - windowBounds.minY
        return dx >= 0 && dx <= trafficLightZone.width && dy >= 0 && dy <= trafficLightZone.height
    }

    /// Номер окна оконного сервера, совпадающего по рамке с окном из AX (рамки в одной
    /// системе координат: начало в левом верхнем углу основного экрана).
    public static func matchWindowID(
        frame: CGRect,
        pid: Int32,
        records: [CGWindowRecord],
        tolerance: CGFloat = 2
    ) -> UInt32? {
        records.first { r in
            r.ownerPID == pid
                && r.layer == 0
                && abs(r.bounds.minX - frame.minX) <= tolerance
                && abs(r.bounds.minY - frame.minY) <= tolerance
                && abs(r.bounds.width - frame.width) <= tolerance
                && abs(r.bounds.height - frame.height) <= tolerance
        }?.windowID
    }
}
