import Foundation
import Testing
@testable import NextSet

struct LocalizationTests {
    private func bundle(_ language: String) throws -> Bundle {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        return try #require(Bundle(path: path))
    }

    @Test func englishAndKoreanResourcesResolve() throws {
        let english = try bundle("en")
        let korean = try bundle("ko")
        #expect(String(localized: "Settings", bundle: english, locale: Locale(identifier: "en")) == "Settings")
        #expect(String(localized: "Settings", bundle: korean, locale: Locale(identifier: "ko")) == "설정")
        #expect(String(localized: "Time to start set \(3)", bundle: english, locale: Locale(identifier: "en")) == "Time to start set 3")
        #expect(String(localized: "Time to start set \(3)", bundle: korean, locale: Locale(identifier: "ko")) == "세트 3 시작할 시간")
        #expect(english.localizedString(forKey: "CFBundleDisplayName", value: nil, table: "InfoPlist") == "NextSet")
        #expect(korean.localizedString(forKey: "CFBundleDisplayName", value: nil, table: "InfoPlist") == "다음세트")
    }

    @Test func countsUseEnglishPluralsAndKoreanOrder() throws {
        let english = try bundle("en")
        let korean = try bundle("ko")
        for count in [0, 1, 2, 20] {
            let expected = count == 1 ? "1 set" : "\(count) sets"
            #expect(String(localized: "\(count) sets", bundle: english, locale: Locale(identifier: "en")) == expected)
            #expect(String(localized: "\(count) sets", bundle: korean, locale: Locale(identifier: "ko")) == "\(count)세트")
            let rest = "0:30"
            let summary = String(localized: "\(count) sets · Rest \(rest)", bundle: english, locale: Locale(identifier: "en"))
            #expect(summary == "\(expected) · Rest 0:30")
        }
    }

    @Test func bothPrivacyDocumentsAreBundled() throws {
        for (language, opening) in [("en", "NextSet is a workout rest timer"), ("ko", "다음세트는")] {
            let url = try #require(try bundle(language).url(forResource: "PrivacyPolicy", withExtension: "txt"))
            let text = try String(contentsOf: url, encoding: .utf8)
            #expect(text.hasPrefix(opening))
            #expect(text.contains("jm.jongminlee@gmail.com"))
        }
    }
}
