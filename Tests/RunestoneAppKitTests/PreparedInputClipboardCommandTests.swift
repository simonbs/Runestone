#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class PreparedInputClipboardCommandTests: XCTestCase {
    func testCopyAndCutPreserveSelectedEmojiAndCRLFAndUndoRedo() throws {
        let initial = "A👩🏽‍💻\r\nB"
        let fixture = try ClipboardFixture(initial)
        let selection = (initial as NSString).range(of: "👩🏽‍💻\r\n")
        XCTAssertEqual(fixture.adapter.setSelection(selection), .processed)
        XCTAssertEqual(fixture.perform(.copy), .processed)
        XCTAssertEqual(fixture.pasteboard.value, "👩🏽‍💻\r\n")
        XCTAssertEqual(fixture.owner.text, initial)
        XCTAssertFalse(fixture.owner.undo.canUndo)
        XCTAssertEqual(fixture.perform(.cut), .processed)
        XCTAssertEqual(Array(fixture.owner.text.utf8), Array("AB".utf8))
        XCTAssertEqual(fixture.pasteboard.value, "👩🏽‍💻\r\n")
        XCTAssertTrue(fixture.owner.undo.canUndo)
        fixture.owner.undo.undo()
        XCTAssertEqual(Array(fixture.owner.text.utf8), Array(initial.utf8))
        XCTAssertTrue(fixture.owner.undo.canRedo)
        fixture.owner.undo.redo()
        XCTAssertEqual(Array(fixture.owner.text.utf8), Array("AB".utf8))
    }

    func testPastePreservesMixedLineEndingsAndBareLF() throws {
        let fixture = try ClipboardFixture("first\r\nlast")
        let selection = (fixture.owner.text as NSString).range(of: "last")
        XCTAssertEqual(fixture.adapter.setSelection(selection), .processed)
        let pasted = "A\nB\rC\r\nD\u{2028}E\u{2029}"
        fixture.pasteboard.value = pasted
        XCTAssertEqual(fixture.perform(.paste), .processed)
        let expected = "first\r\n" + pasted
        XCTAssertEqual(Array(fixture.owner.text.utf8), Array(expected.utf8))
        fixture.pasteboard.value = "\n"
        XCTAssertEqual(fixture.perform(.paste), .processed)
        XCTAssertEqual(Array(fixture.owner.text.utf8), Array((expected + "\n").utf8))
    }

    func testSelectionMustBeNonemptyAndAtComposedCharacterBoundaries() throws {
        let original = "a\u{301}👩🏽‍💻\r\nz"
        let fixture = try ClipboardFixture(original)
        XCTAssertFalse(fixture.canPerform(.copy))
        XCTAssertFalse(fixture.canPerform(.cut))
        XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: 1, length: 1)), .processed)
        XCTAssertFalse(fixture.canPerform(.copy))
        XCTAssertEqual(fixture.perform(.cut), .failed(.init(reason: .invalidSelection, effect: .notApplied), needsReset: false))
        XCTAssertTrue(fixture.pasteboard.writes.isEmpty)
        XCTAssertEqual(fixture.owner.text, original)
        let emoji = (original as NSString).range(of: "👩🏽‍💻")
        XCTAssertEqual(fixture.adapter.setSelection(emoji), .processed)
        XCTAssertTrue(fixture.canPerform(.copy))
        XCTAssertEqual(fixture.perform(.copy), .processed)
        XCTAssertEqual(fixture.pasteboard.value, "👩🏽‍💻")
    }

    func testSelectionCannotSplitCRLFDelimiter() throws {
        let fixture = try ClipboardFixture("a\r\nb")
        XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: 2, length: 1)), .processed)
        XCTAssertFalse(fixture.canPerform(.copy))
        XCTAssertEqual(fixture.perform(.cut), .failed(.init(reason: .invalidSelection, effect: .notApplied), needsReset: false))
        XCTAssertEqual(fixture.owner.text, "a\r\nb")
        XCTAssertTrue(fixture.pasteboard.writes.isEmpty)
    }

    func testEmptyMarkedCompositionDisablesClipboardOperations() throws {
        let fixture = try ClipboardFixture("abc")
        XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: 0, length: 1)), .processed)
        XCTAssertEqual(fixture.adapter.setMarkedText("", selectedRange: NSRange(location: 0, length: 0),
                                                     replacementRange: NSRange(location: NSNotFound, length: 0)), .processed)
        fixture.pasteboard.value = "external"
        for operation in [PreparedInputClipboardCommand.Operation.copy, .cut, .paste] {
            XCTAssertFalse(fixture.canPerform(operation))
            XCTAssertEqual(fixture.perform(operation), .failed(.init(reason: .compositionActive, effect: .notApplied), needsReset: false))
        }
        XCTAssertEqual(fixture.owner.text, "abc")
        XCTAssertEqual(fixture.pasteboard.reads, 0)
        XCTAssertTrue(fixture.pasteboard.writes.isEmpty)
    }

    func testFailedClipboardWriteDoesNotDeleteSelection() throws {
        let fixture = try ClipboardFixture("abc")
        XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: 0, length: 2)), .processed)
        fixture.pasteboard.writeSucceeds = false
        XCTAssertEqual(fixture.perform(.cut), .failed(.init(reason: .unavailable, effect: .mayHaveApplied), needsReset: false))
        XCTAssertEqual(fixture.owner.text, "abc")
        XCTAssertFalse(fixture.owner.undo.canUndo)
    }

    func testCutDoesNotDeleteAfterStaleClipboardWriteCallout() throws {
        let fixture = try ClipboardFixture("secret")
        XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: 0, length: 6)), .processed)
        fixture.pasteboard.onWrite = {
            fixture.owner.text = "new document"
            fixture.owner.revision = UUID()
        }
        XCTAssertEqual(fixture.perform(.cut), .failed(.init(reason: .unavailable, effect: .mayHaveApplied), needsReset: true))
        XCTAssertEqual(fixture.pasteboard.value, "secret")
        XCTAssertEqual(fixture.owner.text, "new document")
        XCTAssertFalse(fixture.owner.undo.canUndo)
        fixture.pasteboard.onWrite = nil
    }

    func testPasteDoesNotUseSelectionAfterReadCalloutChangesDocument() throws {
        let fixture = try ClipboardFixture("old")
        fixture.pasteboard.value = "payload"
        fixture.pasteboard.onRead = {
            fixture.owner.text = "new"
            fixture.owner.revision = UUID()
        }
        XCTAssertEqual(fixture.perform(.paste), .failed(.init(reason: .unavailable, effect: .mayHaveApplied), needsReset: true))
        XCTAssertEqual(fixture.owner.text, "new")
        XCTAssertFalse(fixture.owner.undo.canUndo)
        fixture.pasteboard.onRead = nil
    }

    func testSelectionChangedDuringClipboardWriteDoesNotCutTheOldRange() throws {
        let fixture = try ClipboardFixture("abc")
        XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: 0, length: 2)), .processed)
        fixture.pasteboard.onWrite = {
            XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: 2, length: 1)), .processed)
        }
        XCTAssertEqual(fixture.perform(.cut), .failed(.init(reason: .unavailable, effect: .mayHaveApplied), needsReset: false))
        XCTAssertEqual(fixture.owner.text, "abc")
        XCTAssertEqual(fixture.pasteboard.value, "ab")
        XCTAssertFalse(fixture.owner.undo.canUndo)
        fixture.pasteboard.onWrite = nil
    }

    func testStaleDocumentNeverReadsOrWritesClipboard() throws {
        let fixture = try ClipboardFixture("secret")
        XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: 0, length: 6)), .processed)
        fixture.owner.text = "new"
        fixture.owner.revision = UUID()
        XCTAssertNotEqual(fixture.perform(.copy), .processed)
        XCTAssertTrue(fixture.pasteboard.writes.isEmpty)
        XCTAssertEqual(fixture.pasteboard.reads, 0)
    }

    func testRetirementDuringClipboardCalloutDoesNotDelete() throws {
        let fixture = try ClipboardFixture("secret")
        XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: 0, length: 6)), .processed)
        fixture.pasteboard.onWrite = { fixture.view.quarantineInputViewWithoutCallouts() }
        XCTAssertEqual(fixture.perform(.cut), .failed(.init(reason: .unavailable, effect: .mayHaveApplied), needsReset: false))
        XCTAssertEqual(fixture.owner.text, "secret")
        XCTAssertFalse(fixture.owner.undo.canUndo)
        fixture.pasteboard.onWrite = nil
    }

    func testMismatchedViewCannotCopyAnotherDocumentsSelection() throws {
        let fixture = try ClipboardFixture("private")
        XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: 0, length: 7)), .processed)
        let other = ReadOnlyDocumentView(content: NSAttributedString(string: "another"))
        XCTAssertFalse(PreparedInputClipboardCommand.canPerform(.copy, adapter: fixture.adapter, view: other,
                                                                 pasteboard: fixture.pasteboard))
        XCTAssertEqual(PreparedInputClipboardCommand.perform(.copy, adapter: fixture.adapter, view: other,
                                                              pasteboard: fixture.pasteboard),
                       .failed(.init(reason: .unavailable, effect: .notApplied), needsReset: false))
        XCTAssertTrue(fixture.pasteboard.writes.isEmpty)
    }

    func testBusyParentRejectsClipboardBeforeAnyPasteboardCallAndNeverReplays() throws {
        let fixture = try ClipboardDispatchFixture("secret")
        try fixture.select(NSRange(location: 0, length: 6))
        fixture.host.busy = true
        fixture.pasteboard.value = "payload"
        XCTAssertFalse(fixture.perform(.copy))
        XCTAssertFalse(fixture.perform(.paste))
        XCTAssertEqual(fixture.pasteboard.reads, 0)
        XCTAssertTrue(fixture.pasteboard.writes.isEmpty)
        XCTAssertEqual(fixture.host.text, "secret")
        XCTAssertEqual(fixture.host.undoCount, 0)
        XCTAssertEqual(fixture.host.completions.suffix(2).map(\.outcome),
                       [.rejectedBeforeAdmission(.busy), .rejectedBeforeAdmission(.busy)])
        fixture.host.busy = false
        fixture.queue.runAll()
        XCTAssertEqual(fixture.pasteboard.reads, 0)
        XCTAssertTrue(fixture.pasteboard.writes.isEmpty)
        XCTAssertEqual(fixture.host.text, "secret")
        try fixture.disconnect()
    }

    func testAdmittedCutAndPasteUseParentAndChildGates() throws {
        let original = "A👩🏽‍💻\r\nB"
        let fixture = try ClipboardDispatchFixture(original)
        let selected = (original as NSString).range(of: "👩🏽‍💻\r\n")
        try fixture.select(selected)
        let parents = fixture.host.parentStarts
        let children = fixture.host.childStarts
        XCTAssertTrue(fixture.perform(.cut))
        XCTAssertEqual(fixture.pasteboard.value, "👩🏽‍💻\r\n")
        XCTAssertEqual(fixture.host.text, "AB")
        XCTAssertEqual(fixture.host.undoCount, 1)
        fixture.pasteboard.value = "x\ry\nz\u{2028}"
        XCTAssertTrue(fixture.perform(.paste))
        XCTAssertEqual(Array(fixture.host.text.utf8), Array("Ax\ry\nz\u{2028}B".utf8))
        XCTAssertEqual(fixture.host.undoCount, 2)
        XCTAssertEqual(fixture.host.parentStarts - parents, 2)
        XCTAssertEqual(fixture.host.childStarts - children, 2)
        XCTAssertEqual(fixture.host.parentStarts, fixture.host.parentCloses)
        XCTAssertEqual(fixture.host.childStarts, fixture.host.childCloses)
        XCTAssertEqual(fixture.host.completions.suffix(2).map(\.outcome), [.completed, .completed])
        fixture.queue.runAll()
        XCTAssertEqual(fixture.host.undoCount, 2)
        try fixture.disconnect()
    }

    func testFocusInterruptionDuringCutWriteReportsUncertaintyWithoutDeleting() throws {
        let fixture = try ClipboardDispatchFixture("secret")
        try fixture.select(NSRange(location: 0, length: 6))
        fixture.pasteboard.onWrite = {
            fixture.connection.suspendForFocusLoss()
            fixture.queue.runAll() // A nested loop must not discard the active context.
            XCTAssertEqual(fixture.host.text, "secret")
            XCTAssertEqual(fixture.host.undoCount, 0)
        }
        XCTAssertTrue(fixture.perform(.cut))
        fixture.pasteboard.onWrite = nil
        XCTAssertEqual(fixture.pasteboard.value, "secret")
        XCTAssertEqual(fixture.host.text, "secret")
        XCTAssertEqual(fixture.host.undoCount, 0)
        XCTAssertEqual(fixture.host.completions.last?.outcome, .mayHaveApplied)
        XCTAssertEqual(fixture.connection.takeInputFailures().records.last?.failure.effect, .mayHaveApplied)
        fixture.queue.runAll()
        XCTAssertEqual(fixture.host.text, "secret")
        XCTAssertEqual(fixture.host.undoCount, 0)
        try fixture.disconnect()
    }

    func testSystemPasteboardUsesStandardPlainStringType() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let clipboard = PreparedInputClipboardCommand.SystemPasteboard(board: board)
        let value = "a\r\nb\nc\rd\u{2028}"
        XCTAssertTrue(clipboard.writePlainText(value))
        XCTAssertTrue(clipboard.hasPlainText)
        XCTAssertTrue(board.types?.contains(.string) == true)
        XCTAssertEqual(Array((clipboard.readPlainText() ?? "").utf8), Array(value.utf8))
    }
    func testFocusLossDuringChildAdmissionCannotApplyCutOrPaste() throws {
        for operation in [PreparedInputClipboardCommand.Operation.cut, .paste] {
            let fixture = try ClipboardDispatchFixture("abc")
            try fixture.select(NSRange(location: 0, length: 2))
            fixture.pasteboard.value = "replacement"
            fixture.host.onBeginChild = { fixture.connection.suspendForFocusLoss() }
            XCTAssertTrue(fixture.perform(operation))
            fixture.host.onBeginChild = nil
            XCTAssertEqual(fixture.host.text, "abc")
            XCTAssertEqual(fixture.host.undoCount, 0)
            XCTAssertEqual(fixture.host.completions.last?.outcome, .mayHaveApplied)
            fixture.queue.runAll()
            XCTAssertEqual(fixture.host.text, "abc")
            try fixture.disconnect()
        }
    }

    func testResponderMenuValidationReflectsSelectionClipboardCompositionAndDetach() throws {
        let fixture = try ClipboardDispatchFixture("abc")
        func allowed(_ name: String) -> Bool {
            fixture.view.canPerformEditingAction(NSSelectorFromString(name), connection: fixture.connection,
                adapter: fixture.attachment.adapter, pasteboard: fixture.pasteboard)
        }
        XCTAssertFalse(allowed("copy:"))
        XCTAssertFalse(allowed("cut:"))
        XCTAssertFalse(allowed("paste:"))
        XCTAssertFalse(allowed("undo:")) // The host has not opted in to history.
        XCTAssertFalse(allowed("transpose:"))
        XCTAssertTrue(allowed("selectAll:"))
        XCTAssertTrue(allowed("moveForward:"))
        XCTAssertFalse(allowed("moveRight:")) // This fixture has no visual layout.
        XCTAssertFalse(allowed("deleteBackward:"))
        XCTAssertTrue(allowed("deleteForward:"))
        try fixture.select(NSRange(location: 0, length: 2))
        XCTAssertTrue(allowed("copy:"))
        XCTAssertTrue(allowed("cut:"))
        fixture.pasteboard.value = "x\r\ny"
        XCTAssertTrue(allowed("paste:"))
        XCTAssertTrue(fixture.connection.performCoordinatedInput {
            _ = fixture.attachment.adapter.setMarkedTextReporting("", selectedRange: NSRange(location: 0, length: 0),
                replacementRange: NSRange(location: NSNotFound, length: 0))
        })
        XCTAssertFalse(allowed("copy:"))
        XCTAssertFalse(allowed("cut:"))
        XCTAssertFalse(allowed("paste:"))
        XCTAssertFalse(allowed("selectAll:"))
        try fixture.disconnect()
        XCTAssertFalse(allowed("copy:"))
        XCTAssertFalse(allowed("paste:"))
    }
}

private final class ClipboardFixture {
    let owner: ClipboardOwner
    let view: ReadOnlyDocumentView
    let adapter: PreparedInputEventAdapter
    let pasteboard = ClipboardFakePasteboard()
    init(_ text: String) throws {
        let owner = ClipboardOwner(text)
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: text))
        self.owner = owner
        self.view = view
        adapter = try XCTUnwrap(PreparedInputEventAdapter(view: view, snapshot: view.content,
            initialRevision: owner.revision, documentRevision: { owner.revision }, typingAttributes: { [:] },
            beginEvent: { owner.begin($0) }, beginReconstruction: { owner.reconstruct() }, requestReset: {}))
    }
    func canPerform(_ operation: PreparedInputClipboardCommand.Operation) -> Bool {
        PreparedInputClipboardCommand.canPerform(operation, adapter: adapter, view: view, pasteboard: pasteboard)
    }
    func perform(_ operation: PreparedInputClipboardCommand.Operation) -> PreparedInputClipboardCommand.Result {
        PreparedInputClipboardCommand.perform(operation, adapter: adapter, view: view, pasteboard: pasteboard)
    }
}

private final class ClipboardFakePasteboard: PreparedInputClipboardCommand.Pasteboard {
    var value: String?
    var reads = 0
    var writes: [String] = []
    var writeSucceeds = true
    var onRead: (() -> Void)?
    var onWrite: (() -> Void)?
    var hasPlainText: Bool { value != nil }
    func readPlainText() -> String? { reads += 1; onRead?(); return value }
    func writePlainText(_ value: String) -> Bool { writes.append(value); self.value = value; onWrite?(); return writeSucceeds }
}

private final class ClipboardOwner {
    var text: String
    var revision = UUID()
    var busy = false
    let undo = UndoManager()
    init(_ text: String) { self.text = text; undo.groupsByEvent = false }
    func begin(_ expected: UUID) -> PreparedInputEventAdapter.ReservationResult {
        guard revision == expected else { return .stale }
        guard !busy else { return .busy }
        busy = true
        return .reserved(.init(prepare: { [self] candidate in
            let old = text
            let replacement = candidate.string
            return .init(publish: { [self] in text = replacement; revision = UUID() }, finish: { [self] in
                undo.beginUndoGrouping()
                undo.registerUndo(withTarget: self) { $0.restore(old) }
                undo.endUndoGrouping()
            }, reconcile: { _ in XCTFail("Unexpected reconciliation") })
        }, close: { [self] in busy = false }))
    }
    func reconstruct() -> PreparedInputEventAdapter.ReconstructionStart {
        guard !busy else { return .busy }
        busy = true
        return .reserved(.init(snapshot: NSAttributedString(string: text), revision: revision, close: { [self] in busy = false }))
    }
    func restore(_ value: String) {
        let previous = text
        undo.registerUndo(withTarget: self) { $0.restore(previous) }
        text = value
        revision = UUID()
    }
}
private final class ClipboardDispatchFixture {
    let host: ClipboardDispatchHost
    let queue: ClipboardDispatchQueue
    let attachment: PreparedInputDocumentAttachment
    let view: PreparedInputResponderView
    let connection: PreparedInputContextConnection
    let pasteboard = ClipboardFakePasteboard()

    init(_ text: String) throws {
        let host = ClipboardDispatchHost(text)
        let queue = ClipboardDispatchQueue()
        let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attachResponder(
            host: host, lifetime: host.lifetime, bridge: host.bridge,
            makeDriver: { _ in ClipboardDispatchDriver() }, schedule: queue.enqueue))
        self.host = host
        self.queue = queue
        self.attachment = attachment
        self.view = try XCTUnwrap(attachment.view as? PreparedInputResponderView)
        self.connection = attachment.connection
        XCTAssertTrue(connection.resumeForFocus())
    }

    func select(_ range: NSRange) throws {
        var attempt: PreparedInputEventAdapter.InputAttempt?
        XCTAssertTrue(connection.performCoordinatedInput {
            attempt = self.attachment.adapter.setSelectionReporting(range)
        })
        XCTAssertEqual(try XCTUnwrap(attempt).outcome, .processed)
    }

    func perform(_ operation: PreparedInputClipboardCommand.Operation) -> Bool {
        connection.performCoordinatedInput {
            self.view.routeClipboard(operation, on: self.connection, pasteboard: self.pasteboard)
        }
    }

    func disconnect() throws {
        if !attachment.disconnect() { queue.runAll() }
        XCTAssertTrue(attachment.disconnect())
    }
}

private final class ClipboardDispatchHost: RunestoneInputDispatchHost {
    let lifetime = RunestoneInputDocumentLifetime()
    let bridge = RunestoneInputDocumentBridge()
    var text: String
    var inputRevision = UUID()
    var busy = false
    var parentOpen = false
    var childOpen = false
    var parentStarts = 0
    var parentCloses = 0
    var childStarts = 0
    var childCloses = 0
    var undoCount = 0
    var completions: [RunestoneInputDispatchCompletion] = []
    var onBeginChild: (() -> Void)?

    init(_ text: String) { self.text = text }
    func typingAttributes(for source: ReadOnlyDocumentView) -> [NSAttributedString.Key: Any] { [:] }
    func beginInputEvent(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputEventStart { .busy }
    func beginInputDispatch(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputDispatchStart {
        guard !busy && !parentOpen else { return .busy }
        guard expectedRevision == inputRevision else { return .stale }
        parentOpen = true
        parentStarts += 1
        return .reserved(ClipboardDispatchParent(self))
    }
    func beginInputReconstruction() -> RunestoneInputReconstructionStart {
        guard !busy && !parentOpen else { return .busy }
        busy = true
        return .reserved(ClipboardDispatchSnapshot(self))
    }
    func inputDispatchDidComplete(_ completion: RunestoneInputDispatchCompletion, source: ReadOnlyDocumentView) {
        XCTAssertFalse(parentOpen)
        XCTAssertFalse(childOpen)
        completions.append(completion)
    }
}

private final class ClipboardDispatchParent: RunestoneInputDispatchReservation {
    let host: ClipboardDispatchHost
    init(_ host: ClipboardDispatchHost) { self.host = host }
    func beginInputOperation(expectedRevision: UUID) -> RunestoneInputEventStart {
        XCTAssertTrue(host.parentOpen)
        guard !host.childOpen else { return .busy }
        guard expectedRevision == host.inputRevision else { return .stale }
        host.childOpen = true
        host.childStarts += 1
        host.onBeginChild?()
        return .reserved(ClipboardDispatchChild(host))
    }
    func close() {
        XCTAssertTrue(host.parentOpen)
        XCTAssertFalse(host.childOpen)
        host.parentOpen = false
        host.parentCloses += 1
    }
}

private final class ClipboardDispatchChild: RunestoneInputEventReservation {
    let host: ClipboardDispatchHost
    init(_ host: ClipboardDispatchHost) { self.host = host }
    func prepare(candidate: NSAttributedString) -> RunestoneInputPreparedPublication? {
        ClipboardDispatchPublication(host, text: candidate.string)
    }
    func close() {
        XCTAssertTrue(host.parentOpen)
        XCTAssertTrue(host.childOpen)
        host.childOpen = false
        host.childCloses += 1
    }
}

private final class ClipboardDispatchPublication: RunestoneInputPreparedPublication {
    let host: ClipboardDispatchHost
    let text: String
    init(_ host: ClipboardDispatchHost, text: String) { self.host = host; self.text = text }
    func publish() { host.text = text; host.inputRevision = UUID() }
    func finish() { host.undoCount += 1 }
    func reconcile(_ phase: RunestoneInputReconciliationPhase) { XCTFail("Unexpected reconciliation") }
}

private final class ClipboardDispatchSnapshot: RunestoneInputReconstructionReservation {
    let host: ClipboardDispatchHost
    let snapshot: NSAttributedString
    let revision: UUID
    init(_ host: ClipboardDispatchHost) {
        self.host = host
        self.snapshot = NSAttributedString(string: host.text)
        self.revision = host.inputRevision
    }
    func close() { host.busy = false }
}

private final class ClipboardDispatchDriver: PreparedInputContextConnection.Driver {
    let object = NSObject()
    var associationTarget: NSObject { object }
    func activate() {}
    func handle(_ event: NSEvent) -> Bool { false }
    func invalidateCoordinates() {}
    func discardMarkedText() {}
    func deactivate() {}
}

private final class ClipboardDispatchQueue {
    private var work: [() -> Void] = []
    func enqueue(_ body: @escaping () -> Void) { work.append(body) }
    func runAll() {
        var count = 0
        while !work.isEmpty && count < 200 { count += 1; work.removeFirst()() }
        XCTAssertTrue(work.isEmpty, "The input queue must settle without polling")
    }
}
#endif
