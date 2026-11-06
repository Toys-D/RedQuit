import Testing
@testable import RedQuitCore

@Suite("Исключения")
struct ExclusionRulesTests {
    let own = "com.toysforminds.RedQuit"

    @Test("Программа без bundle ID не трогается")
    func noBundleID() {
        #expect(ExclusionRules.reason(bundleID: nil, userExclusions: [], ownBundleID: own) != nil)
        #expect(ExclusionRules.reason(bundleID: "", userExclusions: [], ownBundleID: own) != nil)
    }

    @Test("Сама утилита всегда в исключениях")
    func ownApp() {
        #expect(ExclusionRules.reason(bundleID: own, userExclusions: [], ownBundleID: own) != nil)
    }

    @Test("Системные процессы всегда в исключениях, регистр не важен")
    func builtIn() {
        #expect(ExclusionRules.reason(bundleID: "com.apple.dock", userExclusions: [], ownBundleID: own) != nil)
        #expect(ExclusionRules.reason(bundleID: "com.apple.Dock", userExclusions: [], ownBundleID: own) != nil)
        #expect(ExclusionRules.reason(bundleID: "com.apple.loginwindow", userExclusions: [], ownBundleID: own) != nil)
    }

    @Test("Finder в исключениях по умолчанию, но это обычная запись")
    func finderDefault() {
        #expect(ExclusionRules.defaultUserExclusions.contains("com.apple.finder"))
        #expect(!ExclusionRules.isBuiltIn("com.apple.finder"))
        let user = Set(ExclusionRules.defaultUserExclusions)
        #expect(ExclusionRules.reason(bundleID: "com.apple.finder", userExclusions: user, ownBundleID: own) != nil)
        // Если Finder удалили из списка — он больше не исключение.
        #expect(ExclusionRules.reason(bundleID: "com.apple.finder", userExclusions: [], ownBundleID: own) == nil)
    }

    @Test("Пользовательское исключение, регистр не важен")
    func userExclusion() {
        #expect(ExclusionRules.reason(bundleID: "com.apple.Safari", userExclusions: ["com.apple.safari"], ownBundleID: own) != nil)
        #expect(ExclusionRules.reason(bundleID: "com.apple.TextEdit", userExclusions: ["com.apple.safari"], ownBundleID: own) == nil)
    }
}
