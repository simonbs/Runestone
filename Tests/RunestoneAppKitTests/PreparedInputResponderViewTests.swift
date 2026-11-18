#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class PreparedInputResponderViewTests: XCTestCase {
    func testNonKeyFirstResponderRemainsInertAndDoesNotExposeContext() throws {
        _ = NSApplication.shared
        let host = ResponderTestHost("abc")
        let queue = ResponderTestQueue()
        var driver: ResponderTestDriver?
        let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attachResponder(
            host: host, lifetime: host.lifetime, bridge: host.bridge,
            makeDriver: { client in
                let created = ResponderTestDriver(client)
                driver = created
                return created
            }, schedule: queue.enqueue))
        let view = try XCTUnwrap(attachment.view as? PreparedInputResponderView)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 160, height: 80),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        XCTAssertTrue(window.makeFirstResponder(view))
        XCTAssertFalse(window.isKeyWindow)
        XCTAssertNil(view.inputContext)
        XCTAssertEqual(driver?.client?.selectedRange().location, NSNotFound)
        driver?.client?.insertText("bad", replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertEqual(host.text, "abc")
        XCTAssertEqual(host.undoCount, 0)
        XCTAssertFalse(attachment.disconnect())
        queue.runAll()
        XCTAssertTrue(attachment.disconnect())
        window.close()
    }

    func testCommandRoutingReportsBlockedAndUnsupportedWithoutDuplicateForwarding() throws {
        let host = ResponderTestHost("abc")
        let queue = ResponderTestQueue()
        let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attachResponder(
            host: host, lifetime: host.lifetime, bridge: host.bridge,
            makeDriver: { ResponderTestDriver($0) }, schedule: queue.enqueue))
        let view = try XCTUnwrap(attachment.view as? PreparedInputResponderView)
        let connection = attachment.connection
        XCTAssertTrue(connection.resumeForFocus())
        XCTAssertEqual(attachment.adapter.setMarkedText("", selectedRange: NSRange(location: 0, length: 0),
                                                        replacementRange: NSRange(location: NSNotFound, length: 0)), .processed)
        var forwarded = 0
        view.routeCommand(NSSelectorFromString("deleteBackward:"), on: connection) { _ in forwarded += 1; return true }
        XCTAssertEqual(forwarded, 0)
        var batch = connection.takeInputFailures()
        XCTAssertEqual(batch.records, [.init(operation: .command,
                                              failure: .init(reason: .compositionActive, effect: .notApplied))])
        XCTAssertEqual(batch.overflowCount, 0)
        XCTAssertEqual(host.text, "abc")
        XCTAssertEqual(host.undoCount, 0)
        view.routeCommand(NSSelectorFromString("transpose:"), on: connection) { _ in forwarded += 1; return true }
        batch = connection.takeInputFailures()
        XCTAssertEqual(forwarded, 0)
        XCTAssertEqual(batch.records, [.init(operation: .command,
                                              failure: .init(reason: .unsupported, effect: .notApplied))])
        XCTAssertFalse(attachment.disconnect())
        queue.runAll()
        XCTAssertTrue(attachment.disconnect())
    }

    func testBusySelectionCommandIsReportedOnceAndNeverReplayed() throws {
        let host = ResponderTestHost("abc")
        let queue = ResponderTestQueue()
        let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attachResponder(
            host: host, lifetime: host.lifetime, bridge: host.bridge,
            makeDriver: { ResponderTestDriver($0) }, schedule: queue.enqueue))
        let view = try XCTUnwrap(attachment.view as? PreparedInputResponderView)
        let connection = attachment.connection
        XCTAssertTrue(connection.resumeForFocus())
        host.busy = true
        var forwarded = 0
        view.routeCommand(NSSelectorFromString("moveForward:"), on: connection) { _ in forwarded += 1; return true }
        let batch = connection.takeInputFailures()
        XCTAssertEqual(batch.records, [.init(operation: .command,
                                              failure: .init(reason: .busy, effect: .notApplied))])
        XCTAssertEqual(batch.overflowCount, 0)
        XCTAssertEqual(forwarded, 0)
        XCTAssertEqual(host.text, "abc")
        XCTAssertEqual(host.undoCount, 0)
        queue.runAll()
        host.busy = false
        connection.resumeAfterQuiescing()
        XCTAssertEqual(attachment.adapter.selectedRangeForInput(), NSRange(location: 0, length: 0))
        XCTAssertTrue(connection.takeInputFailures().records.isEmpty)
        XCTAssertEqual(host.text, "abc")
        XCTAssertEqual(host.undoCount, 0)
        XCTAssertFalse(attachment.disconnect())
        queue.runAll()
        XCTAssertTrue(attachment.disconnect())
    }

    func testOutOfBandKeyBindingCallbacksReportRatherThanDisappear() throws {
        let host = ResponderTestHost("abc")
        let queue = ResponderTestQueue()
        let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attachResponder(
            host: host, lifetime: host.lifetime, bridge: host.bridge,
            makeDriver: { ResponderTestDriver($0) }, schedule: queue.enqueue))
        let view = try XCTUnwrap(attachment.view as? PreparedInputResponderView)
        XCTAssertTrue(attachment.connection.resumeForFocus())
        // No window/focus or active interpretKeyEvents stack: the fallback
        // methods cannot safely apply these out-of-band callbacks.
        view.insertTextFromKeyBinding("x")
        view.doCommandFromKeyBinding(NSSelectorFromString("deleteBackward:"))
        XCTAssertEqual(attachment.connection.takeInputFailures().records, [
            .init(operation: .insertText, failure: .init(reason: .unavailable, effect: .notApplied)),
            .init(operation: .command, failure: .init(reason: .unavailable, effect: .notApplied))
        ])
        XCTAssertEqual(host.text, "abc")
        XCTAssertEqual(host.undoCount, 0)
        XCTAssertFalse(attachment.disconnect())
        queue.runAll()
        XCTAssertTrue(attachment.disconnect())
    }

    func testInlinePredictionTraitTracksConfigurationWithoutForcingSystemPreference() throws {
        let host = ResponderTestHost("Please let me kn")
        let queue = ResponderTestQueue()
        let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attachResponder(
            host: host, lifetime: host.lifetime, bridge: host.bridge,
            makeDriver: { ResponderTestDriver($0) }, schedule: queue.enqueue))
        defer {
            _ = attachment.disconnect()
            queue.runAll()
        }
        let client = try XCTUnwrap(attachment.connection.nativeTextCheckingController?.client)
        XCTAssertEqual(client.inlinePredictionType, .default)
        attachment.view.displayConfiguration.allowsInlinePredictions = false
        XCTAssertEqual(client.inlinePredictionType, .no)
        attachment.view.displayConfiguration.allowsInlinePredictions = true
        XCTAssertEqual(client.inlinePredictionType, .default)
        XCTAssertEqual(host.text, "Please let me kn")
        XCTAssertEqual(host.undoCount, 0)
    }

    func testNativeSpellingCorrectionAndReversionPreserveCaretAndUndo() throws {
        try XCTSkipUnless(NSSpellChecker.isAutomaticSpellingCorrectionEnabled)
        let original = "recieved"
        let checker = NSSpellChecker.shared
        let word = NSRange(location: 0, length: original.utf16.count)
        let language = (checker.automaticallyIdentifiesLanguages
            ? checker.language(forWordRange: word, in: original, orthography: nil) : nil) ?? checker.language()
        guard let correction = checker.correction(forWordRange: word, in: original, language: language,
                                                      inSpellDocumentWithTag: 0), correction != original else {
            throw XCTSkip("The active spelling language does not correct the English test word.")
        }
        let host = ResponderTestHost(original)
        let queue = ResponderTestQueue()
        let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attachResponder(
            host: host, lifetime: host.lifetime, bridge: host.bridge,
            makeDriver: { ResponderTestDriver($0) }, schedule: queue.enqueue))
        defer {
            _ = attachment.disconnect()
            queue.runAll()
        }
        let connection = attachment.connection
        XCTAssertTrue(connection.resumeForFocus())
        XCTAssertTrue(connection.setSelectionForTextFinder(NSRange(location: word.length, length: 0)))
        connection.insertTextFromKeyBinding(" ", replacementRange: NSRange(location: NSNotFound, length: 0))

        let checked = expectation(description: "spelling check ran after input")
        DispatchQueue.main.async { checked.fulfill() }
        wait(for: [checked], timeout: 5)

        XCTAssertEqual(host.text, correction + " ")
        XCTAssertEqual(connection.inputState()?.selection, NSRange(location: correction.utf16.count + 1, length: 0))
        XCTAssertEqual(host.undoCount, 2)

        connection.insertTextFromKeyBinding("x", replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertTrue(connection.revertSpellingCorrection())
        XCTAssertEqual(host.text, original + " x")
        XCTAssertEqual(connection.inputState()?.selection, NSRange(location: word.length + 2, length: 0))
        XCTAssertEqual(host.undoCount, 4)
        XCTAssertFalse(connection.revertSpellingCorrection())
    }

    func testNativeCapitalizationAppliesWithSpellingCorrectionDisabled() throws {
        try XCTSkipUnless(NSSpellChecker.isAutomaticCapitalizationEnabled)
        let original = "then i"
        let word = NSRange(location: 5, length: 1)
        let types: NSTextCheckingResult.CheckingType = [.spelling, .correction]
        let nativeResults = NSSpellChecker.shared.check(
            original, range: word, types: types.rawValue, options: [.automaticCapitalizationEnabledKey: true],
            inSpellDocumentWithTag: 0, orthography: nil, wordCount: nil
        )
        try XCTSkipUnless(nativeResults.contains {
            $0.resultType == .correction && $0.range == word && $0.replacementString == "I"
        }, "The active spelling language must supply this English capitalization.")

        let host = ResponderTestHost(original)
        let queue = ResponderTestQueue()
        let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attachResponder(
            host: host, lifetime: host.lifetime, bridge: host.bridge,
            makeDriver: { ResponderTestDriver($0) }, schedule: queue.enqueue))
        defer {
            _ = attachment.disconnect()
            queue.runAll()
        }
        attachment.view.displayConfiguration.correctsSpellingAutomatically = false
        let connection = attachment.connection
        XCTAssertTrue(connection.resumeForFocus())
        XCTAssertTrue(connection.setSelectionForTextFinder(NSRange(location: original.utf16.count, length: 0)))
        connection.insertTextFromKeyBinding(" ", replacementRange: NSRange(location: NSNotFound, length: 0))

        let checked = expectation(description: "native capitalization ran after input")
        DispatchQueue.main.async { checked.fulfill() }
        wait(for: [checked], timeout: 5)

        XCTAssertEqual(host.text, "then I ")
        XCTAssertEqual(host.undoCount, 2)
        XCTAssertTrue(connection.revertSpellingCorrection())
        XCTAssertEqual(host.text, original + " ")
    }

    func testNativeCapitalizationUsesPunctuationAndSentenceContext() throws {
        try XCTSkipUnless(NSSpellChecker.isAutomaticCapitalizationEnabled)
        let types: NSTextCheckingResult.CheckingType = [.spelling, .correction]
        let probe = NSSpellChecker.shared.check(
            "then i,", range: NSRange(location: 5, length: 1), types: types.rawValue,
            options: [.automaticCapitalizationEnabledKey: true], inSpellDocumentWithTag: 0,
            orthography: nil, wordCount: nil
        )
        try XCTSkipUnless(probe.contains { $0.resultType == .correction && $0.replacementString == "I" })
        for (original, delimiter, expected) in [
            ("then i", ",", "then I,"),
            ("hello. there", " ", "hello. There "),
        ] {
            let host = ResponderTestHost(original)
            let queue = ResponderTestQueue()
            let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attachResponder(
                host: host, lifetime: host.lifetime, bridge: host.bridge,
                makeDriver: { ResponderTestDriver($0) }, schedule: queue.enqueue))
            defer {
                _ = attachment.disconnect()
                queue.runAll()
            }
            attachment.view.displayConfiguration.correctsSpellingAutomatically = false
            let connection = attachment.connection
            XCTAssertTrue(connection.resumeForFocus())
            XCTAssertTrue(connection.setSelectionForTextFinder(NSRange(location: original.utf16.count, length: 0)))
            connection.insertTextFromKeyBinding(delimiter, replacementRange: NSRange(location: NSNotFound, length: 0))
            let applied = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in host.text == expected }, object: nil)
            wait(for: [applied], timeout: 5)
            XCTAssertEqual(host.text, expected)
            XCTAssertEqual(host.undoCount, 2)
        }
    }

    func testStaleCommandReportsUnavailableInsteadOfForwarding() throws {
        let host = ResponderTestHost("abc")
        let queue = ResponderTestQueue()
        let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attachResponder(
            host: host, lifetime: host.lifetime, bridge: host.bridge,
            makeDriver: { ResponderTestDriver($0) }, schedule: queue.enqueue))
        let view = try XCTUnwrap(attachment.view as? PreparedInputResponderView)
        let connection = attachment.connection
        XCTAssertTrue(connection.resumeForFocus())
        host.text = "newer"
        host.inputRevision = UUID()
        var forwarded = false
        view.routeCommand(NSSelectorFromString("insertTab:"), on: connection) { _ in forwarded = true; return true }
        XCTAssertFalse(forwarded)
        XCTAssertEqual(connection.takeInputFailures().records,
                       [.init(operation: .command, failure: .init(reason: .unavailable, effect: .notApplied))])
        XCTAssertEqual(host.text, "newer")
        XCTAssertEqual(host.undoCount, 0)
        queue.runAll()
        XCTAssertFalse(attachment.disconnect())
        queue.runAll()
        XCTAssertTrue(attachment.disconnect())
    }

    func testAbandonedAttachmentImmediatelyRetiresRetainedResponder() throws {
        let host = ResponderTestHost("abc")
        let queue = ResponderTestQueue()
        var attachment: PreparedInputDocumentAttachment? = PreparedInputDocumentAttachment.attachResponder(
            host: host, lifetime: host.lifetime, bridge: host.bridge,
            makeDriver: { ResponderTestDriver($0) }, schedule: queue.enqueue)
        let view = try XCTUnwrap(attachment?.view as? PreparedInputResponderView)
        XCTAssertFalse(view.isRetired)
        attachment = nil
        XCTAssertTrue(view.isRetired)
        XCTAssertFalse(view.acceptsFirstResponder)
        XCTAssertNil(view.inputContext)
        XCTAssertEqual(view.content.string, "")
    }
}

private final class ResponderTestDriver: PreparedInputContextConnection.Driver {
    weak var client: NSTextInputClient?
    private let object = NSObject()
    init(_ client: NSTextInputClient) { self.client = client }
    var associationTarget: NSObject { object }
    var inputContext: NSTextInputContext? { nil }
    func activate() {}
    func handle(_ event: NSEvent) -> Bool { false }
    func invalidateCoordinates() {}
    func discardMarkedText() {}
    func deactivate() {}
}

private final class ResponderTestHost: RunestoneInputDocumentHost {
    var text: String
    var inputRevision = UUID()
    let lifetime = RunestoneInputDocumentLifetime()
    let bridge = RunestoneInputDocumentBridge()
    var busy = false
    var undoCount = 0
    init(_ text: String) { self.text = text }
    func beginInputEvent(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputEventStart {
        guard !busy else { return .busy }
        guard expectedRevision == inputRevision else { return .stale }
        busy = true
        return .reserved(ResponderEventLease(self))
    }
    func beginInputReconstruction() -> RunestoneInputReconstructionStart {
        guard !busy else { return .busy }
        busy = true
        return .reserved(ResponderSnapshotLease(self))
    }
    func typingAttributes(for source: ReadOnlyDocumentView) -> [NSAttributedString.Key: Any] { [:] }
}

private final class ResponderEventLease: RunestoneInputEventReservation {
    let host: ResponderTestHost
    init(_ host: ResponderTestHost) { self.host = host }
    func prepare(candidate: NSAttributedString) -> RunestoneInputPreparedPublication? {
        ResponderPublication(host, text: candidate.string)
    }
    func close() { host.busy = false }
}

private final class ResponderPublication: RunestoneInputPreparedPublication {
    let host: ResponderTestHost
    let text: String
    init(_ host: ResponderTestHost, text: String) { self.host = host; self.text = text }
    func publish() { host.text = text; host.inputRevision = UUID() }
    func finish() { host.undoCount += 1 }
    func reconcile(_ phase: RunestoneInputReconciliationPhase) { XCTFail("Unexpected reconciliation") }
}

private final class ResponderSnapshotLease: RunestoneInputReconstructionReservation {
    let host: ResponderTestHost
    let snapshot: NSAttributedString
    let revision: UUID
    init(_ host: ResponderTestHost) {
        self.host = host
        snapshot = NSAttributedString(string: host.text)
        revision = host.inputRevision
    }
    func close() { host.busy = false }
}

private final class ResponderTestQueue {
    private var pending: [() -> Void] = []
    func enqueue(_ block: @escaping () -> Void) { pending.append(block) }
    func runAll() {
        var limit = 100
        while !pending.isEmpty && limit > 0 {
            limit -= 1
            pending.removeFirst()()
        }
        if !pending.isEmpty { XCTFail("Input queue did not settle") }
    }
}
#endif
