import CoreGraphics

/// Пересчёт координат между AppKit и Quartz/Accessibility.
///
/// - AppKit (`NSEvent.mouseLocation`, `NSScreen.frame`): начало — левый НИЖНИЙ угол
///   основного экрана, ось Y направлена вверх.
/// - Quartz / AX (`CGEvent.location`, `AXUIElementCopyElementAtPosition`): начало — левый
///   ВЕРХНИЙ угол основного экрана, ось Y направлена вниз.
///
/// Обе системы привязаны к одному и тому же «основному» экрану — тому, где строка меню
/// (`NSScreen.screens[0]`, а не `NSScreen.main`, который означает экран активного окна).
/// Поэтому для всех мониторов достаточно отразить Y относительно высоты основного экрана:
/// мониторы слева получают отрицательный X, мониторы сверху — отрицательный Y в AX.
public enum Coordinates {
    public static func quartzPoint(fromAppKit point: CGPoint, primaryScreenHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryScreenHeight - point.y)
    }
}
