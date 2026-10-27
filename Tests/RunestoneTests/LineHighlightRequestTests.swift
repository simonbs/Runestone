import CoreText
@testable import Runestone
import UIKit
import XCTest

@MainActor
final class LineHighlightRequestTests: XCTestCase {
    func testAppearanceCompletionUpdatesExistingControllersAndCaretGeometry() throws {
        let fixture = Fixture(text: String(repeating: "hello אבג 😀\tworld     ", count: 8), width: 150)
        fixture.prepare()
        let rect = CGRect(x: 0, y: 0, width: 150, height: 1_000)
        let displayed = fixture.controller.lineFragmentControllers(in: rect)
        XCTAssertGreaterThan(displayed.count, 1)
        let fragments = displayed.map(\.lineFragment)
        let locations = fragments.flatMap { [$0.visibleRange.location, $0.visibleRange.upperBound] }
        let carets = locations.map { fixture.controller.caretRect(atIndex: $0) }
        fixture.highlighter.complete(0)
        for (index, controller) in displayed.enumerated() {
            let fragment = controller.lineFragment
            XCTAssertEqual(fragment.range, fragments[index].range)
            XCTAssertEqual(fragment.yPosition, fragments[index].yPosition)
            XCTAssertEqual(fragment.baseSize, fragments[index].baseSize)
            XCTAssertFalse(fragment === fragments[index], "Existing renderer controllers must receive new drawing objects.")
            XCTAssertTrue(fixture.controller.lineFragmentNode(atIndex: index).data.lineFragment === fragment,
                          "Selection and frame queries must see the refreshed fragment too.")
            let runs = CTLineGetGlyphRuns(fragment.line) as? [CTRun] ?? []
            XCTAssertFalse(runs.isEmpty)
            for run in runs {
                let attributes = CTRunGetAttributes(run) as NSDictionary
                let color = attributes[NSAttributedString.Key.foregroundColor] as? UIColor
                XCTAssertEqual(color, .red)
            }
        }
        XCTAssertEqual(locations.map { fixture.controller.caretRect(atIndex: $0) }, carets)
    }

    func testFontCompletionReflowsControllerLikeFreshStyledTypesetting() throws {
        let fixture = Fixture(text: String(repeating: "hello world    ", count: 10), width: 150)
        fixture.controller.prepareToDisplayString(toLocation: 150, syntaxHighlightAsynchronously: true)
        let originalHeight = fixture.controller.caretRect(atIndex: 0).height
        fixture.highlighter.complete(0, font: .systemFont(ofSize: 28))
        let string = try XCTUnwrap(fixture.controller.attributedString)
        let fresh = LineTypesetter(lineID: "fresh")
        fresh.constrainingWidth = 150
        fresh.prepareToTypeset(string)
        fresh.typesetLineFragments(toLocation: string.length)
        XCTAssertGreaterThan(fixture.controller.caretRect(atIndex: 0).height, originalHeight)
        XCTAssertEqual(fixture.controller.numberOfLineFragments, fresh.lineFragments.count)
        for expected in fresh.lineFragments {
            let actual = try XCTUnwrap(fixture.controller.lineFragmentNode(atIndex: expected.index).data.lineFragment)
            XCTAssertEqual(actual.range, expected.range)
            XCTAssertEqual(actual.baseSize, expected.baseSize)
            XCTAssertEqual(actual.yPosition, expected.yPosition)
            let caret = fixture.controller.caretRect(atIndex: expected.visibleRange.location)
            XCTAssertEqual(caret.height, expected.baseSize.height)
        }
        XCTAssertEqual(fixture.controller.lineWidth, ceil(fresh.maximumLineWidth))
    }

    func testRepeatedPreparationCompletesOneRequest() throws {
        let fixture = Fixture()
        for _ in 0..<20 { fixture.prepare() }
        XCTAssertEqual(fixture.highlighter.requests.count, 1)
        fixture.highlighter.complete(0)
        fixture.prepare()
        XCTAssertEqual(fixture.highlighter.requests.count, 1)
        XCTAssertEqual(fixture.controller.attributedString?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .red)
    }

    func testCancelledLineCanHighlightOnRevisitWithoutOldCompletionClearingReplacement() {
        let fixture = Fixture()
        fixture.prepare()
        fixture.controller.cancelSyntaxHighlighting()
        XCTAssertFalse(fixture.highlighter.requests[0].input.isValid())
        fixture.prepare()
        fixture.highlighter.complete(0)
        fixture.prepare()
        XCTAssertEqual(fixture.highlighter.requests.count, 2)
        fixture.highlighter.complete(1)
        fixture.prepare()
        XCTAssertEqual(fixture.highlighter.requests.count, 2)
    }

    func testInvalidationRejectsPendingStyles() {
        for invalidate in [
            { (controller: LineController) in controller.invalidateEverything() },
            { $0.invalidateSyntaxHighlighting() },
            { $0.invalidateSyntaxHighlighter() },
            { $0.theme = DefaultTheme() }
        ] {
            let fixture = Fixture()
            fixture.prepare()
            invalidate(fixture.controller)
            XCTAssertFalse(fixture.highlighter.requests[0].input.isValid())
            fixture.prepare()
            fixture.highlighter.complete(0)
            XCTAssertNotEqual(fixture.controller.attributedString?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .red)
            fixture.highlighter.complete(1)
            fixture.prepare()
            XCTAssertEqual(fixture.highlighter.requests.count, 2)
        }
    }

    func testSynchronousDestinationSupersedesPendingRequest() {
        let fixture = Fixture()
        fixture.prepare()
        fixture.controller.prepareToDisplayString(toLocation: 3, syntaxHighlightAsynchronously: false)
        XCTAssertFalse(fixture.highlighter.requests[0].input.isValid())
        XCTAssertEqual(fixture.highlighter.synchronousCount, 1)
        fixture.highlighter.complete(0)
        fixture.prepare()
        XCTAssertEqual(fixture.highlighter.requests.count, 1)
    }
}

private final class Fixture: LineControllerDelegate {
    let controller: LineController
    let highlighter = ControlledHighlighter()

    init(text: String = "let target = 42", width: CGFloat = 320) {
        let string = StringView(string: text)
        let lines = LineManager(stringView: string)
        lines.rebuild()
        controller = LineController(line: lines.firstLine, stringView: string,
                                    invisibleCharacterConfiguration: InvisibleCharacterConfiguration(),
                                    highlightService: HighlightService(lineManager: lines))
        controller.constrainingWidth = width
        controller.delegate = self
    }

    func prepare() {
        controller.prepareToDisplayString(toLocation: 3, syntaxHighlightAsynchronously: true)
    }

    func lineSyntaxHighlighter(for lineController: LineController) -> LineSyntaxHighlighter? { highlighter }
    func lineControllerDidInvalidateLineWidthDuringAsyncSyntaxHighlight(_ lineController: LineController) {}
}

private final class ControlledHighlighter: LineSyntaxHighlighter {
    struct Request {
        let input: LineSyntaxHighlighterInput
        let completion: AsyncCallback
    }
    var theme: Theme = DefaultTheme.shared
    var canHighlight: Bool { true }
    var requests: [Request] = []
    var synchronousCount = 0

    func syntaxHighlight(_ input: LineSyntaxHighlighterInput) {
        synchronousCount += 1
    }
    func syntaxHighlight(_ input: LineSyntaxHighlighterInput, completion: @escaping AsyncCallback) {
        requests.append(Request(input: input, completion: completion))
    }
    func cancel() {}
    func complete(_ index: Int, font: UIFont? = nil) {
        let request = requests[index]
        if request.input.isValid() {
            request.input.attributedString.addAttribute(.foregroundColor, value: UIColor.red,
                                                        range: NSRange(location: 0, length: request.input.attributedString.length))
        }
        if request.input.isValid(), let font {
            request.input.attributedString.addAttribute(.font, value: font,
                                                        range: NSRange(location: 0, length: request.input.attributedString.length))
        }
        // Deliberately deliver an obsolete success: controller ownership must also guard completion.
        request.completion(.success(LineSyntaxHiglighterSetAttributesResult(isSizingInvalid: font != nil)))
    }
}
