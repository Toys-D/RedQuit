import CoreGraphics
import Testing
@testable import RedQuitCore

@Suite("Решение: завершать программу или нет")
struct QuitDeciderTests {
    let standard = AXWindowInfo(subrole: WindowSubrole.standard, isMinimized: false)
    let minimized = AXWindowInfo(subrole: WindowSubrole.standard, isMinimized: true)
    let dialog = AXWindowInfo(subrole: WindowSubrole.dialog, isMinimized: false)
    let otherSpaceWindow = CGWindowRecord(
        windowID: 42, ownerPID: 100, layer: 0,
        bounds: CGRect(x: 0, y: 0, width: 800, height: 600), alpha: 1, isOnscreen: false
    )

    // MARK: «Любое окно»

    @Test("«Любое окно»: обычное окно → завершаем")
    func anyWindowQuits() {
        let d = QuitDecider.decide(mode: .anyWindow, closedWindowSubrole: WindowSubrole.standard,
                                   remainingAX: [standard], otherWindows: [])
        #expect(d.shouldQuit)
    }

    @Test("«Любое окно»: плавающая панель → не завершаем")
    func anyWindowIgnoresFloatingPanel() {
        let d = QuitDecider.decide(mode: .anyWindow, closedWindowSubrole: WindowSubrole.floating,
                                   remainingAX: [], otherWindows: [])
        #expect(!d.shouldQuit)
    }

    @Test("«Любое окно»: системная плавающая панель → не завершаем")
    func anyWindowIgnoresSystemFloatingPanel() {
        let d = QuitDecider.decide(mode: .anyWindow, closedWindowSubrole: WindowSubrole.systemFloating,
                                   remainingAX: nil, otherWindows: [])
        #expect(!d.shouldQuit)
    }

    // MARK: «Последнее окно»

    @Test("«Последнее окно»: осталось обычное окно → не завершаем")
    func lastWindowKeepsWhenStandardRemains() {
        let d = QuitDecider.decide(mode: .lastWindow, closedWindowSubrole: WindowSubrole.standard,
                                   remainingAX: [standard], otherWindows: [])
        #expect(!d.shouldQuit)
    }

    @Test("«Последнее окно»: осталось только свёрнутое окно → не завершаем")
    func lastWindowKeepsWhenMinimizedRemains() {
        let d = QuitDecider.decide(mode: .lastWindow, closedWindowSubrole: WindowSubrole.standard,
                                   remainingAX: [minimized], otherWindows: [])
        #expect(!d.shouldQuit)
        #expect(d.reason.contains("свёрнут"))
    }

    @Test("«Последнее окно»: окон не осталось → завершаем")
    func lastWindowQuitsWhenNothingRemains() {
        let d = QuitDecider.decide(mode: .lastWindow, closedWindowSubrole: WindowSubrole.standard,
                                   remainingAX: [], otherWindows: [])
        #expect(d.shouldQuit)
    }

    @Test("«Последнее окно»: остались только диалоги → завершаем (считаются только обычные окна)")
    func lastWindowIgnoresNonStandardRemaining() {
        let d = QuitDecider.decide(mode: .lastWindow, closedWindowSubrole: WindowSubrole.standard,
                                   remainingAX: [dialog], otherWindows: [])
        #expect(d.shouldQuit)
    }

    @Test("«Последнее окно»: AX не ответил → не завершаем")
    func lastWindowKeepsWhenAXFailed() {
        let d = QuitDecider.decide(mode: .lastWindow, closedWindowSubrole: WindowSubrole.standard,
                                   remainingAX: nil, otherWindows: [])
        #expect(!d.shouldQuit)
    }

    @Test("«Последнее окно»: AX пуст, но система видит окно на другом рабочем столе → не завершаем")
    func lastWindowKeepsWhenWindowOnOtherSpace() {
        let d = QuitDecider.decide(mode: .lastWindow, closedWindowSubrole: WindowSubrole.standard,
                                   remainingAX: [], otherWindows: [otherSpaceWindow])
        #expect(!d.shouldQuit)
    }
}
