import ApplicationServices
import Foundation

/// Тонкие обёртки над Accessibility API. Только чтение атрибутов — RedQuit ничего
/// не нажимает и не меняет в чужих программах.
enum AX {
    static func value(_ element: AXUIElement, _ attribute: String) -> (value: CFTypeRef?, error: AXError) {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return (value, error)
    }

    static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        value(element, attribute).value as? String
    }

    static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        value(element, attribute).value as? Bool
    }

    static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let v = value(element, attribute).value, CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return (v as! AXUIElement)
    }

    /// Список элементов. `list == nil` — атрибут прочитать не удалось (ошибка в `error`).
    /// Отсутствие значения (`.noValue`) считается пустым списком.
    static func elements(_ element: AXUIElement, _ attribute: String) -> (list: [AXUIElement]?, error: AXError) {
        let (v, error) = value(element, attribute)
        switch error {
        case .success: return ((v as? [AXUIElement]) ?? [], error)
        case .noValue: return ([], error)
        default: return (nil, error)
        }
    }

    /// Рамка элемента в глобальных координатах AX (начало — левый верхний угол основного экрана).
    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let positionValue = axValue(element, kAXPositionAttribute),
              let sizeValue = axValue(element, kAXSizeAttribute)
        else { return nil }
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &origin),
              AXValueGetValue(sizeValue, .cgSize, &size)
        else { return nil }
        return CGRect(origin: origin, size: size)
    }

    static func pid(_ element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        return AXUIElementGetPid(element, &pid) == .success ? pid : nil
    }

    private static func axValue(_ element: AXUIElement, _ attribute: String) -> AXValue? {
        guard let v = value(element, attribute).value, CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
        return (v as! AXValue)
    }
}
