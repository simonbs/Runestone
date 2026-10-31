#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class PreparedInputHistoryContractTests: XCTestCase {
    func testSelectAllUsesUTF16SelectionWithoutPublishingOrUndo() throws {
        let owner = HistorySelectionOwner("A😀\r\nB")
        let fixture = try HistorySelectionFixture(owner)
        XCTAssertEqual(fixture.run("selectAll:"), .handled(.init(outcome: .processed, failure: nil)))
        XCTAssertEqual(fixture.adapter.selectedRangeForInput(), NSRange(location: 0, length: 6))
        XCTAssertEqual(owner.text, "A😀\r\nB")
        XCTAssertEqual(owner.publications, 0)
        XCTAssertEqual(owner.starts, owner.closes)
        XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
    }

    func testSelectAllIsBlockedDuringEmptyMarkedComposition() throws {
        let owner = HistorySelectionOwner("abc")
        let fixture = try HistorySelectionFixture(owner)
        XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: 1, length: 1)), .processed)
        XCTAssertEqual(fixture.adapter.setMarkedText("", selectedRange: NSRange(location: 0, length: 0),
                                                     replacementRange: NSRange(location: NSNotFound, length: 0)), .processed)
        let started = owner.starts
        XCTAssertEqual(fixture.run("selectAll:"), .blocked(.init(reason: .compositionActive, effect: .notApplied)))
        XCTAssertEqual(owner.starts, started)
        XCTAssertEqual(owner.text, "abc")
        XCTAssertEqual(owner.publications, 0)
        XCTAssertEqual(fixture.adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
    }

    func testSelectAllRejectsBusyOrStaleDocumentWithoutPublishing() throws {
        for stale in [false, true] {
            let owner = HistorySelectionOwner("abc")
            let fixture = try HistorySelectionFixture(owner)
            if stale {
                owner.text = "newer"
                owner.revision = UUID()
            } else {
                owner.busy = true
            }
            let result = fixture.run("selectAll:")
            if case .handled(let attempt) = result {
                XCTAssertNotEqual(attempt.outcome, .processed)
                XCTAssertNotNil(attempt.failure)
            } else {
                XCTFail("Select All must be recognized and reported")
            }
            XCTAssertEqual(owner.text, stale ? "newer" : "abc")
            XCTAssertEqual(owner.publications, 0)
            owner.busy = false
            XCTAssertEqual(fixture.adapter.reconstructWithoutInputContext(), .processed)
            XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
        }
    }

    func testExistingHostWithoutHistoryImplementationReturnsUnavailable() {
        let host = HistoryDefaultHost()
        let source = ReadOnlyDocumentView(content: NSAttributedString(string: "abc"))
        let expected = host.inputRevision
        XCTAssertFalse(host.canPerformInputHistory(.undo, expectedRevision: expected, source: source))
        XCTAssertEqual(host.performInputHistory(.undo, expectedRevision: expected, source: source), .unavailable)
        XCTAssertEqual(host.performInputHistory(.redo, expectedRevision: expected, source: source), .unavailable)
        XCTAssertEqual(host.inputRevision, expected)
        XCTAssertEqual(host.gateAttempts, 0)
        XCTAssertEqual(source.content.string, "abc")
    }
    func testHistoryMenuCapabilityIsAdvisoryAndDisabledWhilePendingOrStale() throws {
        let fixture = try DeferredHistoryFixture()
        XCTAssertTrue(fixture.connection.canPerformHistory(.undo))
        XCTAssertTrue(fixture.connection.performCoordinatedInput { fixture.connection.requestHistory(.undo) })
        XCTAssertFalse(fixture.connection.canPerformHistory(.undo))
        fixture.queue.runAll()
        XCTAssertFalse(fixture.connection.canPerformHistory(.undo)) // View revision is stale until reconstruction.
        fixture.retire()
    }

    func testResponderHistoryCommandsRunAfterDispatchGateCloses() throws {
        for (selector, operation) in [("undo:", RunestoneInputHistoryOperation.undo),
                                      ("redo:", RunestoneInputHistoryOperation.redo)] {
            let fixture = try DeferredHistoryFixture()
            let initial = fixture.host.inputRevision
            var forwarded = false
            XCTAssertTrue(fixture.connection.performCoordinatedInput {
                fixture.view.routeCommand(NSSelectorFromString(selector), on: fixture.connection) { _ in
                    forwarded = true
                    return true
                }
                XCTAssertTrue(fixture.host.parentOpen)
                fixture.queue.runAll()
                XCTAssertTrue(fixture.host.historyCalls.isEmpty)
            })
            XCTAssertFalse(forwarded)
            XCTAssertTrue(fixture.host.historyCalls.isEmpty)
            fixture.queue.runAll()
            XCTAssertEqual(fixture.host.historyCalls, [operation])
            XCTAssertEqual(fixture.host.historyWasInsideParent, [false])
            let completion = try XCTUnwrap(fixture.host.completions.last { $0.kind == .historyCommand })
            XCTAssertEqual(completion.expectedRevision, initial)
            XCTAssertEqual(completion.finalRevision, fixture.host.inputRevision)
            XCTAssertEqual(completion.outcome, .completed)
            XCTAssertEqual(fixture.host.completions.filter { $0.kind == .historyCommand }.count, 1)
            fixture.retire()
        }
    }

    func testResponderUndoRedoRestoresMixedDelimitersAndReconstructsEachRevision() throws {
        let original = "α\r\nb\nc\rd\u{2028}e\u{2029}"
        let edited = "α!\r\nb\nc\rd\u{2028}e\u{2029}"
        let fixture = try DeferredHistoryFixture(text: edited)
        fixture.host.installHistory(restoring: original)
        fixture.host.historyDidChange = { fixture.connection.requestReset() }
        let editedRevision = fixture.host.inputRevision
        var forwarded = false

        XCTAssertTrue(fixture.connection.performCoordinatedInput {
            fixture.view.routeCommand(NSSelectorFromString("undo:"), on: fixture.connection) { _ in
                forwarded = true
                return true
            }
        })
        fixture.queue.runAll()
        XCTAssertFalse(forwarded)
        XCTAssertEqual(Array(fixture.host.text.utf8), Array(original.utf8))
        XCTAssertEqual(Array(fixture.view.content.string.utf8), Array(original.utf8))
        let undoRevision = fixture.host.inputRevision
        XCTAssertNotEqual(undoRevision, editedRevision)
        XCTAssertTrue(fixture.host.undo.canRedo)
        XCTAssertEqual(fixture.host.completions.last { $0.kind == .historyCommand }?.outcome, .completed)
        XCTAssertEqual(fixture.host.completions.last { $0.kind == .historyCommand }?.finalRevision, undoRevision)
        XCTAssertGreaterThan(fixture.host.reconstructionCount, 0)
        XCTAssertTrue(fixture.connection.resumeForFocus())

        XCTAssertTrue(fixture.connection.performCoordinatedInput {
            fixture.view.routeCommand(NSSelectorFromString("redo:"), on: fixture.connection) { _ in
                forwarded = true
                return true
            }
        })
        fixture.queue.runAll()
        XCTAssertFalse(forwarded)
        XCTAssertEqual(Array(fixture.host.text.utf8), Array(edited.utf8))
        XCTAssertEqual(Array(fixture.view.content.string.utf8), Array(edited.utf8))
        XCTAssertNotEqual(fixture.host.inputRevision, undoRevision)
        XCTAssertTrue(fixture.host.undo.canUndo)
        XCTAssertEqual(fixture.host.historyCalls, [.undo, .redo])
        XCTAssertEqual(fixture.host.historyWasInsideParent, [false, false])
        XCTAssertEqual(fixture.host.completions.filter { $0.kind == .historyCommand }.map(\.outcome), [.completed, .completed])
        XCTAssertEqual(fixture.host.completions.last { $0.kind == .historyCommand }?.finalRevision, fixture.host.inputRevision)
        XCTAssertGreaterThan(fixture.host.reconstructionCount, 1)
        fixture.host.historyDidChange = nil
        fixture.retire()
    }

    func testDuplicateAndLaterInputCannotOvertakePendingHistory() throws {
        let fixture = try DeferredHistoryFixture()
        XCTAssertTrue(fixture.connection.performCoordinatedInput {
            fixture.connection.requestHistory(.undo)
            fixture.connection.requestHistory(.redo)
            XCTAssertTrue(fixture.host.historyCalls.isEmpty)
        })
        let duplicate = fixture.host.completions.filter { $0.kind == .historyCommand }
        XCTAssertEqual(duplicate.count, 1)
        XCTAssertEqual(duplicate[0].outcome, .rejectedBeforeAdmission(.busy))
        var entered = false
        XCTAssertFalse(fixture.connection.performCoordinatedInput { entered = true })
        XCTAssertFalse(entered)
        fixture.queue.runAll()
        XCTAssertEqual(fixture.host.historyCalls, [.undo])
        let results = fixture.host.completions.filter { $0.kind == .historyCommand }
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[1].outcome, .completed)
        XCTAssertNotEqual(results[0].id, results[1].id)
        fixture.retire()
    }

    func testCallbackLaterInSameDispatchCannotOvertakeHistory() throws {
        let fixture = try DeferredHistoryFixture()
        XCTAssertTrue(fixture.connection.performCoordinatedInput {
            fixture.connection.requestHistory(.undo)
            fixture.connection.insertTextFromKeyBinding("X", replacementRange: NSRange(location: NSNotFound, length: 0))
            XCTAssertEqual(fixture.view.content.string, "abc")
            XCTAssertTrue(fixture.host.historyCalls.isEmpty)
        })
        let failures = fixture.connection.takeInputFailures()
        XCTAssertEqual(failures.records.map(\.operation), [.insertText])
        XCTAssertEqual(failures.records.map(\.failure.reason), [.busy])
        XCTAssertEqual(failures.records.map(\.failure.effect), [.notApplied])
        fixture.queue.runAll()
        XCTAssertEqual(fixture.host.historyCalls, [.undo])
        XCTAssertEqual(fixture.view.content.string, "abc")
        XCTAssertEqual(fixture.host.completions.last { $0.kind == .historyCommand }?.outcome, .completed)
        fixture.retire()
    }

    func testPendingHistoryIsRejectedAfterDetachWithoutCallingHost() throws {
        let fixture = try DeferredHistoryFixture()
        XCTAssertTrue(fixture.connection.performCoordinatedInput {
            fixture.connection.requestHistory(.undo)
            XCTAssertFalse(fixture.connection.disconnect())
            fixture.queue.runAll()
            XCTAssertTrue(fixture.host.historyCalls.isEmpty)
        })
        fixture.queue.runAll()
        XCTAssertTrue(fixture.host.historyCalls.isEmpty)
        let completion = try XCTUnwrap(fixture.host.completions.last { $0.kind == .historyCommand })
        XCTAssertEqual(completion.outcome, .rejectedBeforeAdmission(.unavailable))
        XCTAssertEqual(fixture.host.completions.filter { $0.kind == .historyCommand }.count, 1)
        fixture.retire()
    }

    func testDisconnectDuringHistoryWaitsForHostReturnBeforeDiscardingDriver() throws {
        let fixture = try DeferredHistoryFixture()
        fixture.host.onHistory = {
            XCTAssertFalse(fixture.connection.disconnect())
            fixture.queue.runAll() // A nested event loop must not retire the input driver.
            XCTAssertEqual(fixture.driverStats.discards, 0)
        }
        XCTAssertTrue(fixture.connection.performCoordinatedInput { fixture.connection.requestHistory(.undo) })
        fixture.queue.runAll()
        fixture.host.onHistory = nil
        XCTAssertEqual(fixture.host.historyCalls, [.undo])
        XCTAssertEqual(fixture.driverStats.discards, 1)
        let completion = try XCTUnwrap(fixture.host.completions.last { $0.kind == .historyCommand })
        XCTAssertEqual(completion.outcome, .mayHaveApplied)
        XCTAssertEqual(fixture.host.completions.filter { $0.kind == .historyCommand }.count, 1)
        fixture.retire()
    }

    func testHistoryRejectsChangedRevisionWithoutRetry() throws {
        let fixture = try DeferredHistoryFixture()
        let expected = fixture.host.inputRevision
        XCTAssertTrue(fixture.connection.performCoordinatedInput { fixture.connection.requestHistory(.undo) })
        fixture.host.inputRevision = UUID()
        fixture.queue.runAll()
        XCTAssertEqual(fixture.host.historyCalls, [.undo])
        let completion = try XCTUnwrap(fixture.host.completions.last { $0.kind == .historyCommand })
        XCTAssertEqual(completion.expectedRevision, expected)
        XCTAssertEqual(completion.outcome, .rejectedBeforeAdmission(.stale))
        fixture.queue.runAll()
        XCTAssertEqual(fixture.host.historyCalls, [.undo])
        fixture.retire()
    }

    func testHistoryUncertaintyIsReportedOnceAndNeverReplayed() throws {
        let fixture = try DeferredHistoryFixture()
        fixture.host.forcedResult = .mayHaveApplied(finalRevision: nil)
        XCTAssertTrue(fixture.connection.performCoordinatedInput { fixture.connection.requestHistory(.redo) })
        fixture.queue.runAll()
        XCTAssertEqual(fixture.host.historyCalls, [.redo])
        XCTAssertEqual(fixture.host.completions.filter { $0.kind == .historyCommand }.map(\.outcome), [.mayHaveApplied])
        fixture.queue.runAll()
        XCTAssertEqual(fixture.host.historyCalls, [.redo])
        fixture.retire()
    }
}

private final class DeferredHistoryFixture {
    let host: DeferredHistoryHost
    let queue: DeferredHistoryQueue
    let view: PreparedInputResponderView
    let adapter: PreparedInputEventAdapter
    let connection: PreparedInputContextConnection
    let coordinator: PreparedInputDispatchCoordinator
    let driverStats: DeferredHistoryDriverStats

    init(text: String = "abc") throws {
        let host = DeferredHistoryHost(text: text)
        let queue = DeferredHistoryQueue()
        let driverStats = DeferredHistoryDriverStats()
        let source = PreparedInputResponderView(snapshot: NSAttributedString(string: text))
        let inputAdapter = try XCTUnwrap(PreparedInputEventAdapter(view: source, snapshot: source.content,
            initialRevision: host.inputRevision, documentRevision: { host.inputRevision }, typingAttributes: { [:] },
            beginEvent: { _ in .busy }, beginReconstruction: { host.reconstruct() },
            requestReset: {}, schedule: queue.enqueue))
        let inputConnection = try XCTUnwrap(PreparedInputContextConnection(adapter: inputAdapter, view: source,
            makeDriver: { _ in DeferredHistoryDriver(stats: driverStats) }, schedule: queue.enqueue))
        let inputCoordinator = PreparedInputDispatchCoordinator(host: host, source: source, gateReleased: {})
        self.host = host
        self.queue = queue
        self.view = source
        self.adapter = inputAdapter
        self.connection = inputConnection
        self.coordinator = inputCoordinator
        self.driverStats = driverStats
        inputConnection.dispatchCoordinator = inputCoordinator
        source.attach(adapter: inputAdapter, connection: inputConnection)
        XCTAssertTrue(inputConnection.activate())
    }

    func retire() {
        connection.abandonDocument()
        queue.runAll()
    }
}

private final class DeferredHistoryHost: RunestoneInputDispatchHost {
    var inputRevision = UUID()
    var text: String
    let undo = UndoManager()
    var usesRealHistory = false
    var parentOpen = false
    var historyGateOpen = false
    var reconstructionGateOpen = false
    var reconstructionCount = 0
    var historyCalls: [RunestoneInputHistoryOperation] = []
    var historyWasInsideParent: [Bool] = []
    var completions: [RunestoneInputDispatchCompletion] = []
    var forcedResult: RunestoneInputHistoryResult?
    var onHistory: (() -> Void)?
    var historyDidChange: (() -> Void)?

    init(text: String = "abc") {
        self.text = text
        undo.groupsByEvent = false
    }

    func installHistory(restoring original: String) {
        usesRealHistory = true
        undo.beginUndoGrouping()
        undo.registerUndo(withTarget: self) { $0.restore(original) }
        undo.endUndoGrouping()
    }

    private func restore(_ value: String) {
        let previous = text
        undo.registerUndo(withTarget: self) { $0.restore(previous) }
        text = value
        inputRevision = UUID()
    }

    func reconstruct() -> PreparedInputEventAdapter.ReconstructionStart {
        guard !parentOpen, !historyGateOpen, !reconstructionGateOpen else { return .busy }
        reconstructionGateOpen = true
        reconstructionCount += 1
        return .reserved(.init(snapshot: NSAttributedString(string: text), revision: inputRevision,
                               close: { [self] in reconstructionGateOpen = false }))
    }

    func beginInputEvent(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputEventStart { .busy }
    func beginInputReconstruction() -> RunestoneInputReconstructionStart { .busy }
    func typingAttributes(for source: ReadOnlyDocumentView) -> [NSAttributedString.Key: Any] { [:] }
    func beginInputDispatch(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputDispatchStart {
        guard !parentOpen, !historyGateOpen, !reconstructionGateOpen else { return .busy }
        guard expectedRevision == inputRevision else { return .stale }
        parentOpen = true
        return .reserved(DeferredHistoryParent(self))
    }
    func canPerformInputHistory(_ operation: RunestoneInputHistoryOperation, expectedRevision: UUID,
                                source: ReadOnlyDocumentView) -> Bool {
        !parentOpen && !historyGateOpen && !reconstructionGateOpen && expectedRevision == inputRevision
    }
    func performInputHistory(_ operation: RunestoneInputHistoryOperation, expectedRevision: UUID,
                             source: ReadOnlyDocumentView) -> RunestoneInputHistoryResult {
        historyCalls.append(operation)
        historyWasInsideParent.append(parentOpen)
        guard !parentOpen, !historyGateOpen, !reconstructionGateOpen else { return .busy }
        guard expectedRevision == inputRevision else { return .stale }
        historyGateOpen = true
        defer { historyGateOpen = false }
        onHistory?()
        if let result = forcedResult { return result }
        if usesRealHistory {
            switch operation {
            case .undo:
                guard undo.canUndo else { return .unavailable }
                undo.undo()
            case .redo:
                guard undo.canRedo else { return .unavailable }
                undo.redo()
            }
            historyDidChange?()
        } else {
            inputRevision = UUID()
        }
        return .success(finalRevision: inputRevision)
    }
    func inputDispatchDidComplete(_ completion: RunestoneInputDispatchCompletion, source: ReadOnlyDocumentView) {
        completions.append(completion)
    }
}

private final class DeferredHistoryParent: RunestoneInputDispatchReservation {
    let host: DeferredHistoryHost
    init(_ host: DeferredHistoryHost) { self.host = host }
    func beginInputOperation(expectedRevision: UUID) -> RunestoneInputEventStart { .busy }
    func close() { host.parentOpen = false }
}

private final class DeferredHistoryDriverStats {
    var discards = 0
}

private final class DeferredHistoryDriver: PreparedInputContextConnection.Driver {
    let object = NSObject()
    let stats: DeferredHistoryDriverStats
    init(stats: DeferredHistoryDriverStats) { self.stats = stats }
    var associationTarget: NSObject { object }
    func activate() {}
    func handle(_ event: NSEvent) -> Bool { false }
    func invalidateCoordinates() {}
    func discardMarkedText() { stats.discards += 1 }
    func deactivate() {}
}

private final class DeferredHistoryQueue {
    private var work: [() -> Void] = []
    func enqueue(_ body: @escaping () -> Void) { work.append(body) }
    func runAll() {
        var count = 0
        while !work.isEmpty && count < 100 {
            count += 1
            work.removeFirst()()
        }
        XCTAssertTrue(work.isEmpty, "Deferred input work must not poll indefinitely")
    }
}

private final class HistorySelectionFixture {
    let view: ReadOnlyDocumentView
    let adapter: PreparedInputEventAdapter

    init(_ owner: HistorySelectionOwner) throws {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        self.view = view
        adapter = try XCTUnwrap(PreparedInputEventAdapter(view: view, snapshot: view.content,
            initialRevision: owner.revision, documentRevision: { owner.revision }, typingAttributes: { [:] },
            beginEvent: { owner.begin($0) }, beginReconstruction: { owner.reconstruct() }, requestReset: {}))
    }

    func run(_ name: String) -> PreparedInputCommandInterpreter.Result {
        PreparedInputCommandInterpreter.performReporting(NSSelectorFromString(name), adapter: adapter, view: view)
    }
}

private final class HistorySelectionOwner {
    var text: String
    var revision = UUID()
    var busy = false
    var starts = 0
    var closes = 0
    var publications = 0

    init(_ text: String) { self.text = text }

    func begin(_ expected: UUID) -> PreparedInputEventAdapter.ReservationResult {
        guard expected == revision else { return .stale }
        guard !busy else { return .busy }
        busy = true
        starts += 1
        return .reserved(.init(prepare: { [self] candidate in
            .init(publish: { [self] in
                text = candidate.string
                revision = UUID()
                publications += 1
            }, finish: {}, reconcile: { _ in XCTFail("Unexpected conflict") })
        }, close: { [self] in busy = false; closes += 1 }))
    }

    func reconstruct() -> PreparedInputEventAdapter.ReconstructionStart {
        guard !busy else { return .busy }
        busy = true
        return .reserved(.init(snapshot: NSAttributedString(string: text), revision: revision, close: { [self] in busy = false }))
    }
}

private final class HistoryDefaultHost: RunestoneInputDispatchHost {
    var inputRevision = UUID()
    var gateAttempts = 0
    func beginInputEvent(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputEventStart {
        gateAttempts += 1
        return .busy
    }
    func beginInputReconstruction() -> RunestoneInputReconstructionStart { .busy }
    func typingAttributes(for source: ReadOnlyDocumentView) -> [NSAttributedString.Key: Any] { [:] }
    func beginInputDispatch(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputDispatchStart {
        gateAttempts += 1
        return .busy
    }
    func inputDispatchDidComplete(_ completion: RunestoneInputDispatchCompletion, source: ReadOnlyDocumentView) {}
}
#endif
