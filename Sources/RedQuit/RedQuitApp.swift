import AppKit

@main
@MainActor
enum RedQuitApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Без значка в Dock (то же задаёт LSUIElement в Info.plist).
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
