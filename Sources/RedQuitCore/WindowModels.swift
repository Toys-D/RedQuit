import CoreGraphics
import Foundation

/// Значения атрибута AXSubrole для окон.
public enum WindowSubrole {
    public static let standard = "AXStandardWindow"
    public static let dialog = "AXDialog"
    public static let systemDialog = "AXSystemDialog"
    public static let floating = "AXFloatingWindow"
    public static let systemFloating = "AXSystemFloatingWindow"

    /// Окна-диалоги (например, отдельное окно «Сохранить изменения?»).
    public static let dialogs: Set<String> = [dialog, systemDialog]
    /// Плавающие панели и палитры: инспекторы, «Шрифты» и т. п.
    public static let floatingPanels: Set<String> = [floating, systemFloating]
}

/// Окно программы по данным Accessibility API.
public struct AXWindowInfo: Equatable, Sendable {
    public var subrole: String?
    public var isMinimized: Bool

    public init(subrole: String?, isMinimized: Bool) {
        self.subrole = subrole
        self.isMinimized = isMinimized
    }

    public var isStandard: Bool { subrole == WindowSubrole.standard }

    /// Окно считается открытым, если это обычное окно или если оно свёрнуто в Dock
    /// (у свёрнутого окна AX может отдавать другую подроль).
    public var countsAsOpen: Bool { isStandard || isMinimized }
}

/// Окно по данным оконного сервера (`CGWindowListCopyWindowInfo`).
/// Для этих полей разрешение «Запись экрана» не нужно — оно требуется только для заголовков окон.
public struct CGWindowRecord: Equatable, Sendable {
    public var windowID: UInt32
    public var ownerPID: Int32
    public var layer: Int
    public var bounds: CGRect
    public var alpha: Double
    public var isOnscreen: Bool

    public init(windowID: UInt32, ownerPID: Int32, layer: Int, bounds: CGRect, alpha: Double, isOnscreen: Bool) {
        self.windowID = windowID
        self.ownerPID = ownerPID
        self.layer = layer
        self.bounds = bounds
        self.alpha = alpha
        self.isOnscreen = isOnscreen
    }

    /// Разбор одного словаря из `CGWindowListCopyWindowInfo`.
    public init?(dictionary d: [String: Any]) {
        guard let number = (d["kCGWindowNumber"] as? NSNumber)?.uint32Value,
              let pid = (d["kCGWindowOwnerPID"] as? NSNumber)?.int32Value,
              let boundsDict = d["kCGWindowBounds"] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
        else { return nil }
        self.windowID = number
        self.ownerPID = pid
        self.layer = (d["kCGWindowLayer"] as? NSNumber)?.intValue ?? 0
        self.bounds = bounds
        self.alpha = (d["kCGWindowAlpha"] as? NSNumber)?.doubleValue ?? 1
        self.isOnscreen = (d["kCGWindowIsOnscreen"] as? NSNumber)?.boolValue ?? false
    }
}
