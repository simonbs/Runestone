import XCTest

final class SpellCheckingTests: XCTestCase {
    func testCorrectingMisspelledWordAndUndoing() throws {
        let app = XCUIApplication().disablingTextPersistance()
        app.launch()
        app.navigationBars.buttons["Spelling"].tap()
        let textView = try XCTUnwrap(app.textView)
        XCTAssertTrue(textView.waitForExistence(timeout: 5))
        let originalText = "mispelled word.\n\nTap the underlined word to correct it."
        XCTAssertEqual(textView.value as? String, originalText)

        // A single tap offers corrections without double-tapping or showing editing commands.
        let firstWord = app.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: textView.frame.minX + 30, dy: app.navigationBars.firstMatch.frame.maxY + 15)
        )
        firstWord.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        let suggestion = app.descendants(matching: .any).matching(identifier: "misspelled").firstMatch
        XCTAssertTrue(suggestion.waitForExistence(timeout: 5))
        for name in ["Copy", "Ignore Spelling", "Learn Spelling", "Unlearn Spelling"] {
            XCTAssertFalse(app.descendants(matching: .any).matching(identifier: name).firstMatch.exists)
        }
        assertSpellingMenuDismissesAndReopens(in: app, textView: textView, firstWord: firstWord, suggestion: suggestion)
        XCTAssertEqual(textView.value as? String, originalText)
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
        firstWord.tap()
        XCTAssertFalse(suggestion.exists)
        firstWord.doubleTap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "Copy").firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(suggestion.exists)
        XCTAssertEqual(textView.value as? String, originalText)
        attachScreenshot(of: app, named: "Spell checking disabled")
    }

    func testIgnoringSpellingUntilDocumentIsReloaded() throws {
        let app = XCUIApplication().disablingTextPersistance()
        app.launch()
        app.navigationBars.buttons["Dictionary"].tap()
        defer { cleanUpDictionary(in: app) }
        let textView = try XCTUnwrap(app.textView)
        XCTAssertTrue(textView.waitForExistence(timeout: 5))
        let originalText = try XCTUnwrap(textView.value as? String)

        selectFirstWord(in: textView, app: app)
        let ignore = spellingAction(named: "Ignore Spelling", in: app)
        attachScreenshot(of: app, named: "Ignore and learn spelling actions")
        ignore.tap()
        waitForText(originalText, in: textView)
        assertDictionaryState(ignored: true, learned: false, in: app)
        attachScreenshot(of: app, named: "Ignored spelling leaves document unchanged")

        app.navigationBars.buttons["Reload"].tap()
        waitForText(originalText, in: textView)
        assertDictionaryState(ignored: false, learned: false, in: app)
        selectFirstWord(in: textView, app: app)
        XCTAssertTrue(spellingAction(named: "Ignore Spelling", in: app).exists)
        attachScreenshot(of: app, named: "Reload restores spelling checks")
    }

    func testLearningAndUnlearningSpellingWithoutEditingDocument() throws {
        let app = XCUIApplication().disablingTextPersistance()
        app.launch()
        app.navigationBars.buttons["Dictionary"].tap()
        defer { cleanUpDictionary(in: app) }
        let textView = try XCTUnwrap(app.textView)
        XCTAssertTrue(textView.waitForExistence(timeout: 5))
        let originalText = try XCTUnwrap(textView.value as? String)

        selectFirstWord(in: textView, app: app)
        let learn = spellingAction(named: "Learn Spelling", in: app)
        attachScreenshot(of: app, named: "Learn spelling action")
        learn.tap()
        waitForText(originalText, in: textView)
        assertDictionaryState(ignored: false, learned: true, in: app)

        // Learning survives a new document and offers an action on a correctly spelled word.
        app.navigationBars.buttons["Reload"].tap()
        waitForText(originalText, in: textView)
        selectFirstWord(in: textView, app: app)
        let unlearn = spellingAction(named: "Unlearn Spelling", in: app)
        attachScreenshot(of: app, named: "Unlearn a previously learned spelling")
        unlearn.tap()
        waitForText(originalText, in: textView)
        assertDictionaryState(ignored: false, learned: false, in: app)
        selectFirstWord(in: textView, app: app)
        XCTAssertTrue(spellingAction(named: "Ignore Spelling", in: app).exists)
        attachScreenshot(of: app, named: "Unlearning restores spelling checks")
    }

    private func assertSpellingMenuDismissesAndReopens(
        in app: XCUIApplication, textView: XCUIElement, firstWord: XCUICoordinate, suggestion: XCUIElement
    ) {
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let textTop = app.navigationBars.firstMatch.frame.maxY
        let correctlySpelledWord = origin.withOffset(CGVector(dx: textView.frame.minX + 110, dy: textTop + 15))
        let blankLine = origin.withOffset(CGVector(dx: textView.frame.minX + 200, dy: textTop + 160))
        for outside in [correctlySpelledWord, blankLine] {
            outside.tap()
            let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: suggestion)
            XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
            firstWord.tap()
            XCTAssertTrue(suggestion.waitForExistence(timeout: 5))
        }
    }

    private func selectFirstWord(in textView: XCUIElement, app: XCUIApplication) {
        let firstWord = app.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: textView.frame.minX + 30, dy: app.navigationBars.firstMatch.frame.maxY + 15)
        )
        firstWord.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        firstWord.doubleTap()
    }

    private func spellingAction(named name: String, in app: XCUIApplication) -> XCUIElement {
        let action = app.descendants(matching: .any).matching(identifier: name).firstMatch
        if !action.waitForExistence(timeout: 2) {
            let more = app.buttons["More"].firstMatch
            if more.waitForExistence(timeout: 2) {
                more.tap()
            }
        }
        XCTAssertTrue(action.waitForExistence(timeout: 5), "Expected edit-menu action: \(name)")
        return action
    }

    private func assertDictionaryState(ignored: Bool, learned: Bool, in app: XCUIApplication) {
        app.navigationBars.buttons["Inspect"].tap()
        let alert = app.alerts["Dictionary State"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts["Ignored: \(ignored)\nLearned: \(learned)"].exists)
        alert.buttons["Done"].tap()
        // A fresh simulator can present keyboard onboarding when the alert returns focus to the editor.
        let keyboardIntroduction = app.staticTexts["Speed up your typing by sliding your finger across the letters to compose a word."]
        if keyboardIntroduction.exists {
            app.buttons["Continue"].tap()
        }
    }

    private func cleanUpDictionary(in app: XCUIApplication) {
        if app.alerts["Dictionary State"].exists {
            app.alerts["Dictionary State"].buttons["Done"].tap()
        }
        app.navigationBars.buttons["Clean Up"].tap()
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
