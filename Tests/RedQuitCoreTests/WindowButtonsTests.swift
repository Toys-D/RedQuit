import Testing
@testable import RedQuitCore

/// Значения сняты с настоящих окон macOS 27 (ноябрь 2026).
@Suite("Окно настроек или главное окно — по жёлтой и зелёной кнопкам")
struct WindowButtonsTests {
    @Test("Настройки Finder, Safari, TextEdit, Заметок и Launchpad: свернуть и развернуть нельзя → вспомогательное окно")
    func settingsWindowIsAuxiliary() {
        let buttons = WindowButtons(minimizeEnabled: false, zoomEnabled: false, fullScreenEnabled: nil, isFullScreen: false)
        #expect(buttons.isAuxiliary)
    }

    @Test("Обычное окно документа: все кнопки работают → главное окно")
    func documentWindowIsMain() {
        let buttons = WindowButtons(minimizeEnabled: true, zoomEnabled: true, fullScreenEnabled: true, isFullScreen: false)
        #expect(!buttons.isAuxiliary)
    }

    @Test("Калькулятор: зелёная кнопка неактивна, но свернуть можно → главное окно")
    func calculatorIsMain() {
        let buttons = WindowButtons(minimizeEnabled: true, zoomEnabled: false, fullScreenEnabled: nil, isFullScreen: false)
        #expect(!buttons.isAuxiliary)
    }

    @Test("Свернуть нельзя, но зелёная кнопка работает → главное окно")
    func zoomOnlyWindowIsMain() {
        let buttons = WindowButtons(minimizeEnabled: false, zoomEnabled: true, fullScreenEnabled: true, isFullScreen: false)
        #expect(!buttons.isAuxiliary)
    }

    @Test("Окно в полноэкранном режиме: пока заголовок спрятан, AX отдаёт все кнопки неактивными → всё равно главное окно")
    func fullScreenWindowIsMain() {
        let buttons = WindowButtons(minimizeEnabled: false, zoomEnabled: false, fullScreenEnabled: false, isFullScreen: true)
        #expect(!buttons.isAuxiliary)
    }

    @Test("Кнопки прочитать не удалось → считаем окно вспомогательным: при сомнении программу не завершаем")
    func unreadableButtonsAreAuxiliary() {
        let buttons = WindowButtons(minimizeEnabled: nil, zoomEnabled: nil, fullScreenEnabled: nil, isFullScreen: false)
        #expect(buttons.isAuxiliary)
    }
}
