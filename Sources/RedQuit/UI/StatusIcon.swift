import AppKit

/// Значок для строки меню: знак из логотипа (кольцо «выключателя» с красной кнопкой в разрыве),
/// нарисованный кодом как шаблон — macOS сама красит его под светлую и тёмную строку меню.
enum StatusIcon {
    /// - Parameter dimmed: приглушённый значок — RedQuit на паузе.
    static func image(dimmed: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.withAlphaComponent(dimmed ? 0.4 : 1).set()

            // Кольцо с разрывом сверху (по 45° в каждую сторону от вершины).
            let ring = NSBezierPath()
            ring.appendArc(withCenter: NSPoint(x: 9, y: 7.4), radius: 5.4, startAngle: 135, endAngle: 45, clockwise: false)
            ring.lineWidth = 1.8
            ring.lineCapStyle = .round
            ring.stroke()

            // Кнопка в разрыве.
            NSBezierPath(ovalIn: NSRect(x: 9 - 2.4, y: 13.15 - 2.4, width: 4.8, height: 4.8)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
