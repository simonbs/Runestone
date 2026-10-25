import XCTest

final class SpellCheckingTests: XCTestCase {
    func testCorrectingMisspelledWordAndUndoing() throws {
        let app = XCUIApplication().disablingTextPersistance()
        app.launchArguments.append("--spell-checking")
        app.launch()
        let textView = try XCTUnwrap(app.textView)
        XCTAssertTrue(textView.waitForExistence(timeout: 5))
        let originalText = "mispelled word.\n\nSelect the underlined word to correct it."
        XCTAssertEqual(textView.value as? String, originalText)

        // Double-tap the first word at its rendered location below the navigation bar.
        let firstWord = app.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: textView.frame.minX + 30, dy: app.navigationBars.firstMatch.frame.maxY + 15)
        )
        firstWord.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        firstWord.doubleTap()
        let suggestion = app.descendants(matching: .any).matching(identifier: "misspelled").firstMatch
        XCTAssertTrue(suggestion.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "Spelling suggestions")
        suggestion.tap()

        let correctedText = originalText.replacingOccurrences(of: "mispelled", with: "misspelled")
        waitForText(correctedText, in: textView)
        attachScreenshot(of: app, named: "Corrected spelling")
        app.navigationBars.buttons["Undo"].tap()
        waitForText(originalText, in: textView)
        attachScreenshot(of: app, named: "Undo restores original spelling")

        app.navigationBars.buttons["Spelling On"].tap()
        XCTAssertTrue(app.navigationBars.buttons["Spelling Off"].exists)
        firstWord.doubleTap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "Copy").firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(suggestion.exists)
        XCTAssertEqual(textView.value as? String, originalText)
        attachScreenshot(of: app, named: "Spell checking disabled")
    }

    private func waitForText(_ text: String, in textView: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", text), object: textView)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }

    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
