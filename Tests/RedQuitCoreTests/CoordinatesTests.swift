import CoreGraphics
import Testing
@testable import RedQuitCore

@Suite("Пересчёт координат AppKit → Quartz/AX")
struct CoordinatesTests {
    // Основной экран 1512×982 (встроенный экран MacBook Pro 14").
    let primaryHeight: CGFloat = 982

    @Test("Левый верхний угол основного экрана")
    func topLeftOfPrimary() {
        let p = Coordinates.quartzPoint(fromAppKit: CGPoint(x: 0, y: 982), primaryScreenHeight: primaryHeight)
        #expect(p == CGPoint(x: 0, y: 0))
    }

    @Test("Левый нижний угол основного экрана")
    func bottomLeftOfPrimary() {
        let p = Coordinates.quartzPoint(fromAppKit: CGPoint(x: 0, y: 0), primaryScreenHeight: primaryHeight)
        #expect(p == CGPoint(x: 0, y: 982))
    }

    @Test("Монитор над основным: Y в AX становится отрицательным")
    func monitorAbovePrimary() {
        // Второй монитор 1920×1080 стоит над основным: в AppKit его Y от 982 до 2062.
        let p = Coordinates.quartzPoint(fromAppKit: CGPoint(x: 300, y: 2000), primaryScreenHeight: primaryHeight)
        #expect(p == CGPoint(x: 300, y: -1018))
    }

    @Test("Монитор слева: отрицательный X не меняется")
    func monitorLeftOfPrimary() {
        let p = Coordinates.quartzPoint(fromAppKit: CGPoint(x: -1500, y: 500), primaryScreenHeight: primaryHeight)
        #expect(p == CGPoint(x: -1500, y: 482))
    }

    @Test("Монитор под основным: Y в AX больше высоты основного экрана")
    func monitorBelowPrimary() {
        let p = Coordinates.quartzPoint(fromAppKit: CGPoint(x: 100, y: -400), primaryScreenHeight: primaryHeight)
        #expect(p == CGPoint(x: 100, y: 1382))
    }
}
