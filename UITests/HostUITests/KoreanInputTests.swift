import XCTest

final class KoreanInputTests: XCTestCase {
    func testEnteringCombinedCharacter() throws {
        let app = XCUIApplication().disablingTextPersistance()
        app.launch()
        app.textView?.tap()
        app.keys["ㅇ"].tap()
        app.keys["ㅓ"].tap()
        app.keys["ㅍ"].tap()
        XCTAssertEqual(app.textView?.value as? String, "엎")
    }

    func testEnteringTwoCombinedCharacters() throws {
        let app = XCUIApplication().disablingTextPersistance()
        app.launch()
        app.textView?.tap()
        app.keys["ㅇ"].tap()
        app.keys["ㅓ"].tap()
        app.keys["ㅍ"].tap()
        app.keys["ㅇ"].tap()
        app.keys["ㅓ"].tap()
        app.keys["ㅍ"].tap()
        XCTAssertEqual(app.textView?.value as? String, "엎엎")
    }

    func testEnteringThreeCombinedCharacters() throws {
        let app = XCUIApplication().disablingTextPersistance()
        app.launch()
        app.textView?.tap()
        app.keys["ㅇ"].tap()
        app.keys["ㅓ"].tap()
        app.keys["ㅍ"].tap()
        app.keys["ㅇ"].tap()
        app.keys["ㅓ"].tap()
        app.keys["ㅍ"].tap()
        app.keys["ㅇ"].tap()
        app.keys["ㅓ"].tap()
        app.keys["ㅍ"].tap()
        XCTAssertEqual(app.textView?.value as? String, "엎엎엎")
    }

    func testEnteringTwoCombinedCharactersSeparatedBySpace() throws {
        let app = XCUIApplication().disablingTextPersistance()
        app.launch()
        app.textView?.tap()
        app.keys["ㅇ"].tap()
        app.keys["ㅓ"].tap()
        app.keys["ㅍ"].tap()
        app.typeText(" ")
        app.keys["ㅇ"].tap()
        app.keys["ㅓ"].tap()
        app.keys["ㅍ"].tap()
        XCTAssertEqual(app.textView?.value as? String, "엎 엎")
    }

    func testEnteringTwoCombinedCharactersSeparatedByTwoLineBreaks() throws {
        let app = XCUIApplication().disablingTextPersistance()
        app.launch()
        app.textView?.tap()
        app.keys["ㅇ"].tap()
        app.keys["ㅓ"].tap()
        app.keys["ㅍ"].tap()
        app.typeText("\n\n")
        app.keys["ㅇ"].tap()
        app.keys["ㅓ"].tap()
        app.keys["ㅍ"].tap()
        XCTAssertEqual(app.textView?.value as? String, "엎\n\n엎")
    }

    func testEnteringTwoDifferentCombinedCharacters() throws {
        // Test case inspired by a bug report in the Textastic forums:
        // https://feedback.textasticapp.com/communities/1/topics/3570-korean-text-typing-error
        let app = XCUIApplication().disablingTextPersistance()
        app.launch()
        app.textView?.tap()
        app.keys["ㄱ"].tap()
        app.keys["ㅏ"].tap()
        app.keys["ㅇ"].tap()
        app.keys["ㅁ"].tap()
        app.keys["ㅜ"].tap()
        app.keys["ㄹ"].tap()
        XCTAssertEqual(app.textView?.value as? String, "강물")
    }

    func testEnteringKoreanBetweenQuotationMarks() throws {
        let app = XCUIApplication().disablingTextPersistance()
        app.launch()
        app.textView?.tap()
        app.keys["more"].tap()
        app.keys["\""].tap()
        app.keys["more"].tap()
        app.keys["ㅇ"].tap()
        app.keys["ㅓ"].tap()
        XCTAssertEqual(app.textView?.value as? String, "\"어\"")
    }

    func testInsertingKoreanCharactersInTextWithCRLFLineEndings() throws {
        let app = XCUIApplication().disablingTextPersistance().usingCRLFLineEndings()
        app.launch()
        app.textView?.tap()
        app.typeText("테스트")
        app.buttons["Return"].tap()
        app.typeText("TEST")
        app.buttons["Return"].tap()
        app.keys["ㅇ"].tap()
        app.keys["ㅓ"].tap()
        app.keys["ㅍ"].tap()
        XCTAssertEqual(app.textView?.value as? String, "테스트\r\nTEST\r\n엎")
    }
}
