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
}
