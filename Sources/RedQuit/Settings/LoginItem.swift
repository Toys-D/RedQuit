import Foundation
import ServiceManagement

/// Запуск при входе в систему через SMAppService.
@MainActor
enum LoginItem {
    static var status: SMAppService.Status { SMAppService.mainApp.status }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
            Log.app.notice("Open at login enabled (status: \(status.rawValue))")
        } else {
            try SMAppService.mainApp.unregister()
            Log.app.notice("Open at login disabled")
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    /// Автозапуск запоминает путь к программе — надёжнее, когда она лежит в «Программах».
    static var isInApplicationsFolder: Bool {
        Bundle.main.bundleURL.path.hasPrefix("/Applications/")
    }
}
