@testable import Runestone
import UIKit
import XCTest

@MainActor
final class LineHighlightRequestTests: XCTestCase {
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

    init() {
        let string = StringView(string: "let target = 42")
        let lines = LineManager(stringView: string)
        lines.rebuild()
        controller = LineController(line: lines.firstLine, stringView: string,
                                    invisibleCharacterConfiguration: InvisibleCharacterConfiguration(),
                                    highlightService: HighlightService(lineManager: lines))
        controller.constrainingWidth = 320
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
    func complete(_ index: Int) {
        let request = requests[index]
        if request.input.isValid() {
            request.input.attributedString.addAttribute(.foregroundColor, value: UIColor.red,
                                                        range: NSRange(location: 0, length: request.input.attributedString.length))
        }
        // Deliberately deliver an obsolete success: controller ownership must also guard completion.
        request.completion(.success(()))
    }
}
