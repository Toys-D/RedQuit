import CoreGraphics
import Testing
@testable import RedQuitCore

@Suite("Окна по данным оконного сервера (CGWindowList)")
struct WindowRulesTests {
    let pid: Int32 = 100

    func record(_ id: UInt32, pid: Int32 = 100, layer: Int = 0,
                size: CGSize = CGSize(width: 800, height: 600), alpha: Double = 1,
                onscreen: Bool = false, origin: CGPoint = .zero) -> CGWindowRecord {
        CGWindowRecord(windowID: id, ownerPID: pid, layer: layer,
                       bounds: CGRect(origin: origin, size: size), alpha: alpha, isOnscreen: onscreen)
    }

    @Test("Берём только окна нужной программы на обычном уровне, видимые на каком-либо рабочем столе")
    func filtersCandidates() {
        let records = [
            record(1),                                   // подходит
            record(2, pid: 999),                         // чужая программа
            record(3, layer: 25),                        // не обычный уровень (меню, панели)
            record(4, size: CGSize(width: 10, height: 10)), // служебное крошечное окно
            record(5, alpha: 0),                         // прозрачное
            record(6),                                   // спрятано: нет ни на одном рабочем столе
            record(7),                                   // это закрытое окно
        ]
        let result = WindowRules.otherWindows(in: records, pid: pid,
                                              visibleOnAnySpace: [1, 2, 3, 4, 5, 7], excluding: [7])
        #expect(result.map(\.windowID) == [1])
    }

    @Test("Если список окон всех рабочих столов недоступен — не фильтруем по нему (осторожный вариант)")
    func nilVisibilityDoesNotFilter() {
        let result = WindowRules.otherWindows(in: [record(1), record(6)], pid: pid,
                                              visibleOnAnySpace: nil, excluding: [])
        #expect(result.map(\.windowID) == [1, 6])
    }

    @Test("Поиск номера окна по рамке с допуском")
    func matchesWindowByFrame() {
        let records = [
            record(10, origin: CGPoint(x: 100, y: 100)),
            record(11, onscreen: true, origin: CGPoint(x: 500, y: 300)),
            record(12, pid: 999, onscreen: true, origin: CGPoint(x: 500, y: 300)),
        ]
        let frame = CGRect(x: 501, y: 299, width: 800, height: 601)
        #expect(WindowRules.matchWindowID(frame: frame, pid: pid, records: records) == 11)
        #expect(WindowRules.matchWindowID(frame: frame.offsetBy(dx: 50, dy: 0), pid: pid, records: records) == nil)
    }

    @Test("Зона кнопок светофора — левый верхний угол окна")
    func trafficLightZone() {
        let window = CGRect(x: 100, y: 200, width: 800, height: 600)
        #expect(WindowRules.isInTrafficLightZone(point: CGPoint(x: 116, y: 216), windowBounds: window))
        #expect(WindowRules.isInTrafficLightZone(point: CGPoint(x: 160, y: 260), windowBounds: window))
        #expect(!WindowRules.isInTrafficLightZone(point: CGPoint(x: 400, y: 216), windowBounds: window))
        #expect(!WindowRules.isInTrafficLightZone(point: CGPoint(x: 116, y: 400), windowBounds: window))
        #expect(!WindowRules.isInTrafficLightZone(point: CGPoint(x: 90, y: 216), windowBounds: window))
    }

    @Test("Разбор словаря CGWindowListCopyWindowInfo")
    func parsesDictionary() {
        let dict: [String: Any] = [
            "kCGWindowNumber": 77,
            "kCGWindowOwnerPID": 100,
            "kCGWindowLayer": 0,
            "kCGWindowAlpha": 1.0,
            "kCGWindowIsOnscreen": true,
            "kCGWindowBounds": ["X": 10, "Y": 20, "Width": 300, "Height": 200],
        ]
        let r = CGWindowRecord(dictionary: dict)
        #expect(r == CGWindowRecord(windowID: 77, ownerPID: 100, layer: 0,
                                    bounds: CGRect(x: 10, y: 20, width: 300, height: 200),
                                    alpha: 1, isOnscreen: true))
    }
}
