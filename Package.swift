// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RedQuit",
    platforms: [.macOS(.v14)],
    targets: [
        // Логика без системных вызовов: пересчёт координат, правила решений, исключения.
        // Вынесена в отдельный модуль, чтобы её можно было покрыть юнит-тестами.
        .target(name: "RedQuitCore"),
        // Само приложение: монитор кликов, Accessibility API, меню, настройки.
        .executableTarget(
            name: "RedQuit",
            dependencies: ["RedQuitCore"]
        ),
        .testTarget(
            name: "RedQuitCoreTests",
            dependencies: ["RedQuitCore"]
        ),
    ]
)
