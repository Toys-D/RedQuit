import Foundation
import Testing

/// Проверяет переводы интерфейса: во всех языках те же ключи, что в английском,
/// и те же подстановки (%@, %ld) — иначе String(format:) упадёт или покажет мусор.
@Suite("Переводы интерфейса")
struct LocalizationTests {
    static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/Localization")

    static let languages = ["en", "ru", "uk", "es", "pt-BR", "fr", "de", "it", "pl", "tr",
                            "ja", "ko", "zh-Hans", "zh-Hant", "ar", "hi"]

    static func strings(_ language: String) -> [String: String]? {
        let url = directory.appendingPathComponent("\(language).lproj/Localizable.strings")
        return NSDictionary(contentsOf: url) as? [String: String]
    }

    static func placeholders(_ text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "%(?:\\d+\\$)?(@|ld|lld|d)")
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).map { match in
            String(text[Range(match.range(at: 1), in: text)!])
        }.sorted()
    }

    @Test("Английский эталон на месте")
    func englishExists() throws {
        let english = try #require(Self.strings("en"))
        #expect(english.count > 40)
    }

    @Test("Во всех языках те же ключи и подстановки", arguments: languages.dropFirst())
    func sameKeysAndPlaceholders(language: String) throws {
        let english = try #require(Self.strings("en"))
        let translated = try #require(Self.strings(language), "нет файла или он не читается: \(language)")
        #expect(Set(translated.keys) == Set(english.keys), "ключи \(language) не совпадают с английскими")
        for (key, value) in english {
            guard let other = translated[key] else { continue }
            #expect(Self.placeholders(other) == Self.placeholders(value), "\(language): подстановки в «\(key)»")
            #expect(!other.isEmpty, "\(language): пустой перевод «\(key)»")
        }
    }
}
