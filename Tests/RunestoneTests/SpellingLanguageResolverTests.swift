@testable import Runestone
import XCTest

final class SpellingLanguageResolverTests: XCTestCase {
    private let available = ["en_US", "da_DK", "fr_FR"]

    func testAutomaticModeCombinesKeyboardAndPreferredLanguagesWithoutDuplicates() {
        XCTAssertEqual(SpellingLanguageResolver.resolve(explicitLanguage: nil,
                                                        keyboardLanguages: ["en-US", "emoji", "da-DK"],
                                                        preferredLanguages: ["da", "en-GB", "zz-ZZ"],
                                                        availableLanguages: available), ["en_US", "da_DK"])
    }

    func testPreferredLanguagesIncludeCombinedKeyboardsSecondaryLanguage() {
        XCTAssertEqual(SpellingLanguageResolver.resolve(explicitLanguage: nil, keyboardLanguages: ["en-US"],
                                                        preferredLanguages: ["en-US", "da-DK"],
                                                        availableLanguages: available), ["en_US", "da_DK"])
    }

    func testExplicitLanguageRestrictsCheckingAndUnsupportedOverrideDisablesIt() {
        XCTAssertEqual(SpellingLanguageResolver.resolve(explicitLanguage: "da-DK", keyboardLanguages: ["en-US"],
                                                        preferredLanguages: ["fr-FR"], availableLanguages: available), ["da_DK"])
        XCTAssertEqual(SpellingLanguageResolver.resolve(explicitLanguage: "en-GB", keyboardLanguages: ["en-US"],
                                                        preferredLanguages: ["da-DK"], availableLanguages: available), [])
    }

    func testUnavailableAutomaticLanguagesFallBackSafely() {
        XCTAssertEqual(SpellingLanguageResolver.resolve(explicitLanguage: nil, keyboardLanguages: ["emoji"],
                                                        preferredLanguages: ["zz-ZZ"], availableLanguages: available), ["en_US"])
        XCTAssertEqual(SpellingLanguageResolver.resolve(explicitLanguage: nil, keyboardLanguages: [],
                                                        preferredLanguages: [], availableLanguages: []), [])
    }

    func testBareOverridesResolveToAdvertisedDictionaryIdentifiers() {
        let dictionaries = ["en_GB", "en_US", "ru_RU", "pl_PL", "lt_LT", "sl_SI", "hi", "ar"]
        let overrides = ["en": "en_GB", "ru": "ru_RU", "pl": "pl_PL", "lt": "lt_LT",
                         "sl": "sl_SI", "hi": "hi", "ar": "ar"]
        for (requested, expected) in overrides {
            XCTAssertEqual(SpellingLanguageResolver.resolve(explicitLanguage: requested,
                                                            keyboardLanguages: ["en-US"], preferredLanguages: ["da-DK"],
                                                            availableLanguages: dictionaries), [expected], requested)
        }
    }

    func testMatchingReturnsOriginalAdvertisedIdentifierForBothModes() {
        let dictionaries = ["EN-us", "da_DK", "zh-Hant"]
        for (requested, expected) in [("en_US", "EN-us"), ("DA-dk", "da_DK"), ("ZH_hant", "zh-Hant")] {
            XCTAssertEqual(SpellingLanguageResolver.resolve(explicitLanguage: requested,
                                                            keyboardLanguages: [], preferredLanguages: [],
                                                            availableLanguages: dictionaries), [expected])
            XCTAssertEqual(SpellingLanguageResolver.resolve(explicitLanguage: nil,
                                                            keyboardLanguages: [requested], preferredLanguages: [],
                                                            availableLanguages: dictionaries), [expected])
        }
        XCTAssertEqual(SpellingLanguageResolver.resolve(explicitLanguage: "EN", keyboardLanguages: [],
                                                        preferredLanguages: [], availableLanguages: dictionaries), ["EN-us"])
    }

    func testExplicitUnavailableRegionScriptAndLanguageRemainUnavailable() {
        for requested in ["en_GB", "zh_Hans", "zz", ""] {
            XCTAssertEqual(SpellingLanguageResolver.resolve(explicitLanguage: requested,
                                                            keyboardLanguages: ["en-US"], preferredLanguages: ["zh-Hant"],
                                                            availableLanguages: ["en_US", "zh_Hant"]), [], requested)
        }
        XCTAssertEqual(SpellingLanguageResolver.resolve(explicitLanguage: "en", keyboardLanguages: [],
                                                        preferredLanguages: [], availableLanguages: []), [])
    }
}
