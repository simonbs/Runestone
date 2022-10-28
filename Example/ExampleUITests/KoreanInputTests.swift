import XCTest

final class KoreanInputTests: XCTestCase {
    func testEnteringCombinedCharacter() throws {
        let app = XCUIApplication()
        app.launch()
        app.clearTextView()
        app.keys["ㅇ"].tap()
        app.keys["ㅓ"].tap()
        app.keys["ㅍ"].tap()
        XCTAssertEqual(app.textView?.value as? String, "엎")
    }

    func testEnteringTwoCombinedCharacters() throws {
        let app = XCUIApplication()
        app.launch()
        app.clearTextView()
        app.keys["ㅇ"].tap()
        app.keys["ㅓ"].tap()
        app.keys["ㅍ"].tap()
        app.keys["ㅇ"].tap()
        app.keys["ㅓ"].tap()
        app.keys["ㅍ"].tap()
        XCTAssertEqual(app.textView?.value as? String, "엎엎")
    }

    func testEnteringThreeCombinedCharacters() throws {
        let app = XCUIApplication()
        app.launch()
        app.clearTextView()
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
        let app = XCUIApplication()
        app.launch()
        app.clearTextView()
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
        let app = XCUIApplication()
        app.launch()
        app.clearTextView()
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
        let app = XCUIApplication()
        app.launch()
        app.clearTextView()
        app.keys["ㄱ"].tap()
        app.keys["ㅏ"].tap()
        app.keys["ㅇ"].tap()
        app.keys["ㅁ"].tap()
        app.keys["ㅜ"].tap()
        app.keys["ㄹ"].tap()
        XCTAssertEqual(app.textView?.value as? String, "강물")
    }
}

private extension XCUIApplication {
    var textView: XCUIElement? {
        return scrollViews.children(matching: .textView).element
    }

    func clearTextView() {
        textView?.doubleTap()
        collectionViews.staticTexts["Select All"].tap()
        textView?.typeText(XCUIKeyboardKey.delete.rawValue)
    }
}
