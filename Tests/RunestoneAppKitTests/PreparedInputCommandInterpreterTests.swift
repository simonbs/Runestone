#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class PreparedInputCommandInterpreterTests: XCTestCase {
    func testDeletionAndMovementRespectComposedCharactersAndSelection() throws {
        let fixture = try CommandFixture("A👨‍👩‍👧‍👦e\u{301}B")
        let familyLength = ("👨‍👩‍👧‍👦" as NSString).length
        XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: 1, length: 0)), .processed)
        XCTAssertEqual(fixture.run("moveRight:"), .processed)
        XCTAssertEqual(fixture.adapter.selectedRangeForInput(), NSRange(location: 1 + familyLength, length: 0))
        XCTAssertEqual(fixture.run("deleteForward:"), .processed)
        XCTAssertEqual(fixture.owner.text, "A👨‍👩‍👧‍👦B")
        XCTAssertEqual(fixture.owner.undoCount, 1)
        XCTAssertEqual(fixture.run("deleteBackward:"), .processed)
        XCTAssertEqual(fixture.owner.text, "AB")
        XCTAssertEqual(fixture.owner.undoCount, 2)
        XCTAssertEqual(fixture.adapter.selectedRangeForInput(), NSRange(location: 1, length: 0))
        XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: 0, length: 2)), .processed)
        XCTAssertEqual(fixture.run("moveRight:"), .processed)
        XCTAssertEqual(fixture.adapter.selectedRangeForInput(), NSRange(location: 2, length: 0))
        XCTAssertEqual(fixture.run("moveLeft:"), .processed)
        XCTAssertEqual(fixture.adapter.selectedRangeForInput(), NSRange(location: 1, length: 0))
        XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: 0, length: 2)), .processed)
        XCTAssertEqual(fixture.run("deleteBackward:"), .processed)
        XCTAssertEqual(fixture.owner.text, "")
        XCTAssertEqual(fixture.owner.undoCount, 3)
        XCTAssertEqual(fixture.run("deleteBackward:"), .processed)
        XCTAssertEqual(fixture.owner.undoCount, 3)
        XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
    }

    func testDeletionDoesNotEraseAcrossCaretInsideGrapheme() throws {
        for (text, caret) in [("A\u{301}", 1), ("👨‍👩", 2)] {
            let fixture = try CommandFixture(text)
            XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: caret, length: 0)), .processed)
            let started = fixture.owner.started
            XCTAssertNil(fixture.run("deleteBackward:"))
            XCTAssertNil(fixture.run("deleteForward:"))
            XCTAssertEqual(fixture.owner.text, text)
            XCTAssertEqual(fixture.owner.undoCount, 0)
            XCTAssertEqual(fixture.owner.started, started)
            XCTAssertEqual(fixture.adapter.selectedRangeForInput(), NSRange(location: caret, length: 0))
            XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
        }
    }

    func testTabInsertionUsesOneDocumentTransactionAndUndo() throws {
        let fixture = try CommandFixture("ab")
        XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: 1, length: 1)), .processed)
        XCTAssertEqual(fixture.run("insertTab:"), .processed)
        XCTAssertEqual(fixture.owner.text, "a\t")
        XCTAssertEqual(fixture.owner.undoCount, 1)
        XCTAssertEqual(fixture.owner.started, fixture.owner.closed)
        XCTAssertEqual(fixture.adapter.selectedRangeForInput(), NSRange(location: 2, length: 0))
        XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
    }

    func testUnknownAndMarkedCommandsDoNotMutateDocument() throws {
        let fixture = try CommandFixture("abc")
        XCTAssertNil(fixture.run("transpose:"))
        let unspecified = NSRange(location: NSNotFound, length: 0)
        XCTAssertEqual(fixture.adapter.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0),
                                                     replacementRange: unspecified), .processed)
        let started = fixture.owner.started
        for name in ["deleteBackward:", "deleteForward:", "moveLeft:", "moveRight:", "insertNewline:", "insertTab:"] {
            XCTAssertNil(fixture.run(name), name)
        }
        XCTAssertEqual(fixture.owner.started, started)
        XCTAssertEqual(fixture.owner.text, "abc")
        XCTAssertEqual(fixture.view.content.string, "にabc")
        XCTAssertEqual(fixture.adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
    }

    func testEmptyMarkedReplacementDoesNotAllowCommandsToCommitComposition() throws {
        let fixture = try CommandFixture("abc")
        XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: 1, length: 1)), .processed)
        XCTAssertEqual(fixture.adapter.setMarkedText("", selectedRange: NSRange(location: 0, length: 0),
                                                     replacementRange: NSRange(location: NSNotFound, length: 0)), .processed)
        XCTAssertEqual(fixture.adapter.markedRangeForInput().location, NSNotFound)
        XCTAssertEqual(fixture.view.content.string, "ac")
        let started = fixture.owner.started
        for name in ["deleteBackward:", "deleteForward:", "moveLeft:", "moveRight:", "insertTab:"] {
            XCTAssertNil(fixture.run(name), name)
        }
        XCTAssertEqual(fixture.owner.started, started)
        XCTAssertEqual(fixture.owner.text, "abc")
        XCTAssertEqual(fixture.owner.undoCount, 0)
        XCTAssertEqual(fixture.adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertEqual(fixture.view.content.string, "abc")
        XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
    }

    func testReportingDistinguishesUnsupportedBlockedAndBusyCommands() throws {
        let fixture = try CommandFixture("abc")
        XCTAssertEqual(fixture.runReporting("transpose:"), .unsupported)
        XCTAssertEqual(fixture.adapter.setMarkedText("", selectedRange: NSRange(location: 0, length: 0),
                                                     replacementRange: NSRange(location: NSNotFound, length: 0)), .processed)
        XCTAssertEqual(fixture.runReporting("deleteBackward:"),
                       .blocked(.init(reason: .compositionActive, effect: .notApplied)))
        XCTAssertEqual(fixture.owner.text, "abc")
        XCTAssertEqual(fixture.owner.undoCount, 0)
        XCTAssertEqual(fixture.adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: 1, length: 0)), .processed)
        fixture.owner.busy = true
        XCTAssertEqual(fixture.runReporting("moveRight:"),
                       .handled(.init(outcome: .resetRequired,
                                      failure: .init(reason: .busy, effect: .notApplied))))
        XCTAssertEqual(fixture.owner.text, "abc")
        fixture.owner.busy = false
        XCTAssertEqual(fixture.adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertEqual(fixture.owner.undoCount, 0)
        XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
    }

    func testReportingDoesNotDeleteAcrossInteriorGrapheme() throws {
        let fixture = try CommandFixture("A\u{301}B")
        XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: 1, length: 0)), .processed)
        XCTAssertEqual(fixture.runReporting("deleteForward:"),
                       .blocked(.init(reason: .invalidSelection, effect: .notApplied)))
        XCTAssertEqual(fixture.owner.text, "A\u{301}B")
        XCTAssertEqual(fixture.owner.undoCount, 0)
        XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
    }

    func testReportingRejectsCommandAgainstStaleSelectionWithoutMutating() throws {
        let fixture = try CommandFixture("abc")
        fixture.owner.text = "newer"
        fixture.owner.revision = UUID()
        XCTAssertEqual(fixture.runReporting("insertTab:"),
                       .handled(.init(outcome: .resetRequired,
                                      failure: .init(reason: .unavailable, effect: .notApplied))))
        XCTAssertEqual(fixture.owner.text, "newer")
        XCTAssertEqual(fixture.owner.undoCount, 0)
        XCTAssertEqual(fixture.adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
    }

    func testBusyDocumentRejectsCommandWithoutRetryOrUndo() throws {
        let fixture = try CommandFixture("abc")
        fixture.owner.busy = true
        XCTAssertEqual(fixture.run("insertTab:"), .resetRequired)
        XCTAssertEqual(fixture.owner.text, "abc")
        XCTAssertEqual(fixture.owner.undoCount, 0)
        XCTAssertEqual(fixture.owner.started, 0)
        fixture.owner.busy = false
        XCTAssertEqual(fixture.adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
    }
}

private final class CommandFixture {
    let owner: CommandOwner
    let view: ReadOnlyDocumentView
    let adapter: PreparedInputEventAdapter

    init(_ text: String) throws {
        let owner = CommandOwner(text)
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: text))
        self.owner = owner
        self.view = view
        self.adapter = try XCTUnwrap(PreparedInputEventAdapter(view: view, snapshot: view.content,
            initialRevision: owner.revision, documentRevision: { owner.revision }, typingAttributes: { [:] },
            beginEvent: { owner.begin($0) }, beginReconstruction: { owner.reconstruct() }, requestReset: {}))
    }

    func run(_ selector: String) -> PreparedInputEventAdapter.Outcome? {
        PreparedInputCommandInterpreter.perform(NSSelectorFromString(selector), adapter: adapter, view: view)
    }

    func runReporting(_ selector: String) -> PreparedInputCommandInterpreter.Result {
        PreparedInputCommandInterpreter.performReporting(NSSelectorFromString(selector), adapter: adapter, view: view)
    }
}

private final class CommandOwner {
    var text: String
    var revision = UUID()
    var busy = false
    var started = 0
    var closed = 0
    var undoCount = 0
    init(_ text: String) { self.text = text }

    func begin(_ expected: UUID) -> PreparedInputEventAdapter.ReservationResult {
        guard expected == revision else { return .stale }
        guard !busy else { return .busy }
        busy = true
        started += 1
        return .reserved(.init(prepare: { [self] candidate in
            let text = candidate.string
            return .init(publish: { [self] in self.text = text; revision = UUID() },
                         finish: { [self] in undoCount += 1 }, reconcile: { _ in XCTFail("Unexpected conflict") })
        }, close: { [self] in busy = false; closed += 1 }))
    }

    func reconstruct() -> PreparedInputEventAdapter.ReconstructionStart {
        guard !busy else { return .busy }
        busy = true
        return .reserved(.init(snapshot: NSAttributedString(string: text), revision: revision,
                               close: { [self] in busy = false }))
    }
}
#endif
