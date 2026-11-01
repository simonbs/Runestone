import CoreText
@testable import Runestone
import UIKit
import XCTest

@MainActor
final class LineHighlightRequestTests: XCTestCase {
    func testAppearanceCompletionUpdatesExistingControllersAndCaretGeometry() throws {
        let fixture = HighlightRequestFixture(text: String(repeating: "hello אבג 😀\tworld     ", count: 8), width: 150)
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
        let fixture = HighlightRequestFixture(text: String(repeating: "hello world    ", count: 10), width: 150)
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

    func testFontHeightChangeNotifiesLayoutEvenWhenLineWidthIsUnchanged() {
        let fixture = HighlightRequestFixture(text: "\t")
        fixture.prepare()
        let width = fixture.controller.lineWidth
        let height = fixture.controller.lineHeight
        fixture.highlighter.complete(0, font: .systemFont(ofSize: 28))
        XCTAssertEqual(fixture.controller.lineWidth, width)
        XCTAssertGreaterThan(fixture.controller.lineHeight, height)
        XCTAssertEqual(fixture.sizeChangeCount, 1)
    }

    func testRepeatedPreparationCompletesOneRequest() throws {
        let fixture = HighlightRequestFixture()
        for _ in 0..<20 { fixture.prepare() }
        XCTAssertEqual(fixture.highlighter.requests.count, 1)
        fixture.highlighter.complete(0)
        fixture.prepare()
        XCTAssertEqual(fixture.highlighter.requests.count, 1)
        XCTAssertEqual(fixture.controller.attributedString?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .red)
    }

    func testLayoutInvalidationRetainsStyledStringAndReflowsWithoutHighlightingAgain() throws {
        let fixture = HighlightRequestFixture(text: String(repeating: "hello world    ", count: 10), width: 150)
        fixture.controller.prepareToDisplayString(toLocation: 150, syntaxHighlightAsynchronously: true)
        fixture.highlighter.complete(0, font: .systemFont(ofSize: 28))
        let styled = try XCTUnwrap(fixture.controller.attributedString)
        let previousCount = fixture.controller.numberOfLineFragments

        fixture.controller.constrainingWidth = 300
        fixture.controller.lineFragmentHeightMultiplier = 1.5
        fixture.controller.invalidateLayout()
        fixture.controller.prepareToDisplayString(toLocation: 150, syntaxHighlightAsynchronously: true)

        XCTAssertTrue(fixture.controller.attributedString === styled)
        XCTAssertEqual(fixture.highlighter.requests.count, 1)
        XCTAssertEqual(styled.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .red)
        XCTAssertEqual(styled.attribute(.font, at: 0, effectiveRange: nil) as? UIFont, .systemFont(ofSize: 28))
        XCTAssertLessThan(fixture.controller.numberOfLineFragments, previousCount)
        let fresh = LineTypesetter(lineID: "fresh")
        fresh.constrainingWidth = 300
        fresh.lineFragmentHeightMultiplier = 1.5
        fresh.prepareToTypeset(styled)
        fresh.typesetLineFragments(toLocation: 150, additionalLineFragmentCount: 1)
        for expected in fresh.lineFragments {
            let actual = try XCTUnwrap(fixture.controller.lineFragmentNode(atIndex: expected.index).data.lineFragment)
            XCTAssertEqual(actual.range, expected.range)
            XCTAssertEqual(actual.scaledSize, expected.scaledSize)
            XCTAssertEqual(actual.yPosition, expected.yPosition)
        }
        XCTAssertEqual(fixture.controller.lineWidth, ceil(fresh.maximumLineWidth))
    }

    func testLayoutInvalidationKeepsPendingHighlightRequestValid() throws {
        let fixture = HighlightRequestFixture(text: String(repeating: "hello world    ", count: 10), width: 150)
        fixture.prepare()
        let input = fixture.highlighter.requests[0].input
        fixture.controller.constrainingWidth = 220
        fixture.controller.invalidateLayout()
        fixture.prepare()
        XCTAssertTrue(input.isValid())
        XCTAssertEqual(fixture.highlighter.requests.count, 1)
        fixture.highlighter.complete(0, font: .systemFont(ofSize: 28))
        fixture.prepare()
        XCTAssertEqual(fixture.highlighter.requests.count, 1)
        XCTAssertEqual(fixture.controller.attributedString?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .red)
        XCTAssertEqual(fixture.controller.caretRect(atIndex: 0).height, UIFont.systemFont(ofSize: 28).totalLineHeight, accuracy: 1)
    }

    func testCancelledLineCanHighlightOnRevisitWithoutOldCompletionClearingReplacement() {
        let fixture = HighlightRequestFixture()
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
            let fixture = HighlightRequestFixture()
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
        let fixture = HighlightRequestFixture()
        fixture.prepare()
        fixture.controller.prepareToDisplayString(toLocation: 3, syntaxHighlightAsynchronously: false)
        XCTAssertFalse(fixture.highlighter.requests[0].input.isValid())
        XCTAssertEqual(fixture.highlighter.synchronousCount, 1)
        fixture.highlighter.complete(0)
        fixture.prepare()
        XCTAssertEqual(fixture.highlighter.requests.count, 1)
    }
}

final class HighlightRequestFixture: LineControllerDelegate {
    let controller: LineController
    let highlighter = ControlledLineHighlighter()
    private(set) var sizeChangeCount = 0

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
    func lineControllerDidInvalidateLineWidthDuringAsyncSyntaxHighlight(_ lineController: LineController) {
        sizeChangeCount += 1
    }
}

final class ControlledLineHighlighter: LineSyntaxHighlighter {
    struct Request {
        let input: LineSyntaxHighlighterInput
        let completion: AsyncCallback
    }
    var theme: Theme = DefaultTheme.shared
    var canHighlight: Bool { true }
    var requests: [Request] = []
    var synchronousCount = 0
    var synchronousColor = UIColor.red

    func syntaxHighlight(_ input: LineSyntaxHighlighterInput) {
        synchronousCount += 1
        input.attributedString.addAttribute(.foregroundColor, value: synchronousColor,
                                            range: NSRange(location: 0, length: input.attributedString.length))
    }
    func syntaxHighlight(_ input: LineSyntaxHighlighterInput, completion: @escaping AsyncCallback) {
        requests.append(Request(input: input, completion: completion))
    }
    func cancel() {}
    func fail(_ index: Int) {
        requests[index].completion(.failure(TreeSitterSyntaxHighlighterError.cancelled))
    }
    func complete(_ index: Int, font: UIFont? = nil, color: UIColor = .red) {
        let request = requests[index]
        if request.input.isValid() {
            request.input.attributedString.addAttribute(.foregroundColor, value: color,
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
