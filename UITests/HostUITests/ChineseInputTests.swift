import XCTest

final class ChineseInputTests: XCTestCase {
    func testEnteringMarkedText() throws {
        let app = XCUIApplication().disablingTextPersistance()
        app.launch()
        app.textView?.tap()
        app.keys["日"].tap()
        app.keys["十"].tap()
        app.collectionViews.staticTexts["早"].tap()
        XCTAssertEqual(app.textView?.value as? String, "早")
    }

    func testEnteringMarkedTextTwoTimes() throws {
        let app = XCUIApplication().disablingTextPersistance()
        app.launch()
        app.textView?.tap()
        app.keys["日"].tap()
        app.keys["十"].tap()
        app.collectionViews.staticTexts["早"].tap()
        app.keys["日"].tap()
        app.keys["女"].tap()
        app.collectionViews.staticTexts["晨"].tap()
        XCTAssertEqual(app.textView?.value as? String, "早晨")
    }
}
