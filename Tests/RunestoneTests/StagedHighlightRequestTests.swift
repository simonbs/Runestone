import CoreText
@testable import Runestone
import UIKit
import XCTest

@MainActor
final class StagedHighlightRequestTests: XCTestCase {
    func testThemeRefreshRetainsDisplayedStylesUntilStagedHighlightSucceeds() throws {
        let fixture = HighlightRequestFixture()
        fixture.prepare()
        fixture.highlighter.complete(0, font: .systemFont(ofSize: 24))
        let displayed = try XCTUnwrap(fixture.controller.attributedString)
        let oldCaret = fixture.controller.caretRect(atIndex: 0)

        fixture.controller.theme = DefaultTheme()
        fixture.prepare()
        let staged = fixture.highlighter.requests[1].input
        XCTAssertFalse(staged.attributedString === displayed)
        XCTAssertTrue(fixture.controller.attributedString === displayed)
        XCTAssertEqual(displayed.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .red)
        XCTAssertEqual(fixture.controller.caretRect(atIndex: 0), oldCaret)
        for _ in 0..<5 { fixture.prepare() }
        XCTAssertEqual(fixture.highlighter.requests.count, 2, "Preparing a staged refresh must not restart it.")

        fixture.highlighter.complete(1, font: .systemFont(ofSize: 30), color: .blue)
        XCTAssertTrue(fixture.controller.attributedString === staged.attributedString)
        XCTAssertEqual(fixture.controller.attributedString?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .blue)
        XCTAssertGreaterThan(fixture.controller.caretRect(atIndex: 0).height, oldCaret.height)
        let fragment = try XCTUnwrap(fixture.controller.lineFragmentNode(atIndex: 0).data.lineFragment)
        let runs = try XCTUnwrap(CTLineGetGlyphRuns(fragment.line) as? [CTRun])
        XCTAssertFalse(runs.isEmpty)
        for run in runs {
            XCTAssertEqual((CTRunGetAttributes(run) as NSDictionary)[NSAttributedString.Key.foregroundColor] as? UIColor, .blue)
        }
    }

    func testRepeatedThemeChangesRejectObsoleteStagedCompletion() throws {
        let fixture = HighlightRequestFixture()
        fixture.prepare()
        fixture.highlighter.complete(0)
        let displayed = try XCTUnwrap(fixture.controller.attributedString)
        fixture.controller.theme = DefaultTheme()
        fixture.prepare()
        let obsolete = fixture.highlighter.requests[1].input
        fixture.controller.theme = DefaultTheme()
        XCTAssertFalse(obsolete.isValid())
        fixture.prepare()
        fixture.highlighter.complete(1, color: .blue)
        XCTAssertTrue(fixture.controller.attributedString === displayed)
        fixture.prepare()
        XCTAssertEqual(fixture.highlighter.requests.count, 3)
        fixture.highlighter.complete(2, color: .purple)
        XCTAssertEqual(fixture.controller.attributedString?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .purple)
    }

    func testCancelledOrFailedStagedRefreshCanRetryWithoutLosingDisplayedStyles() throws {
        for fails in [false, true] {
            let fixture = HighlightRequestFixture()
            fixture.prepare()
            fixture.highlighter.complete(0)
            let displayed = try XCTUnwrap(fixture.controller.attributedString)
            fixture.controller.theme = DefaultTheme()
            fixture.prepare()
            let abandoned = fixture.highlighter.requests[1].input
            if fails {
                fixture.highlighter.fail(1)
            } else {
                fixture.controller.cancelSyntaxHighlighting()
            }
            XCTAssertFalse(abandoned.isValid())
            XCTAssertTrue(fixture.controller.attributedString === displayed)
            fixture.prepare()
            let replacement = fixture.highlighter.requests[2].input
            XCTAssertFalse(replacement.attributedString === displayed)
            fixture.highlighter.complete(1, color: .blue)
            XCTAssertTrue(fixture.controller.attributedString === displayed)
            fixture.highlighter.complete(2, color: .green)
            fixture.prepare()
            XCTAssertEqual(fixture.highlighter.requests.count, 3)
            XCTAssertTrue(fixture.controller.attributedString === replacement.attributedString)
            XCTAssertEqual(fixture.controller.attributedString?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .green)
        }
    }

    func testSynchronousDestinationSupersedesStagedThemeRefresh() throws {
        let fixture = HighlightRequestFixture()
        fixture.prepare()
        fixture.highlighter.complete(0)
        fixture.controller.theme = DefaultTheme()
        fixture.prepare()
        let abandoned = fixture.highlighter.requests[1].input
        fixture.highlighter.synchronousColor = .purple
        fixture.controller.prepareToDisplayString(toLocation: 3, syntaxHighlightAsynchronously: false)
        XCTAssertFalse(abandoned.isValid())
        XCTAssertEqual(fixture.highlighter.synchronousCount, 1)
        fixture.highlighter.complete(1, color: .blue)
        fixture.prepare()
        XCTAssertEqual(fixture.highlighter.requests.count, 2)
        XCTAssertEqual(fixture.controller.attributedString?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .purple)
    }

    func testLayoutAttributesChangedDuringStagedRefreshSurviveFinalSwap() throws {
        let fixture = HighlightRequestFixture(text: "a\tb")
        fixture.prepare()
        fixture.highlighter.complete(0)
        fixture.controller.theme = DefaultTheme()
        fixture.prepare()
        let staged = fixture.highlighter.requests[1].input
        fixture.controller.kern = 1.25
        fixture.controller.tabWidth = 80
        fixture.prepare()
        XCTAssertTrue(staged.isValid(), "Layout-only attributes must not restart a pending syntax request.")
        XCTAssertEqual(fixture.highlighter.requests.count, 2)
        for string in [try XCTUnwrap(fixture.controller.attributedString), staged.attributedString] {
            XCTAssertEqual((string.attribute(.kern, at: 0, effectiveRange: nil) as? NSNumber)?.doubleValue, 1.25)
            let paragraph = try XCTUnwrap(string.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
            XCTAssertEqual(paragraph.defaultTabInterval, 80)
        }
        fixture.highlighter.complete(1, color: .blue)
        let styled = try XCTUnwrap(fixture.controller.attributedString)
        let fresh = LineTypesetter(lineID: "fresh")
        fresh.constrainingWidth = 320
        fresh.prepareToTypeset(styled)
        fresh.typesetLineFragments(toLocation: styled.length)
        XCTAssertEqual(fixture.controller.lineWidth, ceil(fresh.maximumLineWidth))
        XCTAssertEqual((styled.attribute(.kern, at: 0, effectiveRange: nil) as? NSNumber)?.doubleValue, 1.25)
        XCTAssertEqual((styled.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.defaultTabInterval, 80)
    }
}
