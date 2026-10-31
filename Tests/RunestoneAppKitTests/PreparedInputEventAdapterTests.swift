#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

/// All callbacks and tests run on the main thread.
final class PreparedInputEventAdapterTests: XCTestCase {
    private let unspecified = NSRange(location: NSNotFound, length: 0)

    func testEachCompositionCallbackHasItsOwnLeaseThroughCommitCallbacks() throws {
        let owner = FakeEventOwner(text: "abc")
        let scheduler = EventScheduler()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        var resets = 0
        let adapter = try makeAdapter(view: view, owner: owner, scheduler: scheduler) { resets += 1 }

        XCTAssertEqual(adapter.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0),
                                             replacementRange: unspecified), .processed)
        XCTAssertEqual(view.content.string, "にabc")
        XCTAssertEqual(owner.text, "abc")
        XCTAssertEqual(owner.prepareLeases.count, 0)
        XCTAssertEqual(owner.closedLeases, owner.startedLeases)

        XCTAssertEqual(adapter.setMarkedText("日本", selectedRange: NSRange(location: 2, length: 0),
                                             replacementRange: unspecified), .processed)
        XCTAssertEqual(owner.text, "abc")
        XCTAssertEqual(owner.prepareLeases.count, 0)

        XCTAssertEqual(adapter.insertText("日本", replacementRange: unspecified), .processed)
        XCTAssertEqual(view.content.string, "日本abc")
        XCTAssertEqual(owner.text, "日本abc")
        XCTAssertEqual(owner.startedLeases.count, 3)
        XCTAssertEqual(Set(owner.startedLeases).count, 3)
        XCTAssertEqual(owner.closedLeases, owner.startedLeases)
        XCTAssertEqual(owner.prepareLeases, [owner.startedLeases[2]])
        XCTAssertEqual(owner.publishLeases, owner.prepareLeases)
        XCTAssertEqual(owner.finishLeases, owner.prepareLeases)
        XCTAssertEqual(owner.undoCount, 1)
        XCTAssertEqual(resets, 0)
        XCTAssertEqual(scheduler.count, 0)
        XCTAssertTrue(adapter.disconnectAfterQuiescing())
    }

    func testProvisionalCompositionMustBeResolvedBeforeDisconnect() throws {
        let owner = FakeEventOwner(text: "abc")
        let scheduler = EventScheduler()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(view: view, owner: owner, scheduler: scheduler) {}
        XCTAssertEqual(adapter.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0),
                                             replacementRange: unspecified), .processed)
        XCTAssertFalse(adapter.disconnectAfterQuiescing())
        XCTAssertNil(view.claimInputMutation())
        XCTAssertEqual(adapter.cancelCompositionAfterQuiescing(), .processed)
        XCTAssertEqual(view.content.string, owner.text)
        XCTAssertTrue(adapter.disconnectAfterQuiescing())
    }

    func testStaleCompositionReconstructsFromLatestCanonicalSnapshot() throws {
        let owner = FakeEventOwner(text: "abc")
        let scheduler = EventScheduler()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        var resets = 0
        let adapter = try makeAdapter(view: view, owner: owner, scheduler: scheduler) { resets += 1 }
        XCTAssertEqual(adapter.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0),
                                             replacementRange: unspecified), .processed)
        XCTAssertEqual(view.content.string, "にabc")
        owner.text = "newer"
        owner.revision = UUID()
        XCTAssertEqual(adapter.insertText("x", replacementRange: unspecified), .resetRequired)
        XCTAssertEqual(adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertEqual(view.content.string, "newer")
        XCTAssertEqual(owner.text, "newer")
        XCTAssertEqual(owner.undoCount, 0)
        scheduler.runAll()
        XCTAssertEqual(resets, 0)
        XCTAssertEqual(adapter.insertText("!", replacementRange: unspecified), .processed)
        XCTAssertEqual(owner.text, "!newer")
        XCTAssertTrue(adapter.disconnectAfterQuiescing())
    }

    func testReconstructionConflictRetriesNewestRevisionAndInvalidatesOldReset() throws {
        let original = String(repeating: "line\n", count: 100)
        let owner = FakeEventOwner(text: original)
        let scheduler = EventScheduler()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: original))
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 180, height: 80))
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        var resets = 0
        let adapter = try makeAdapter(view: view, owner: owner, scheduler: scheduler) { resets += 1 }
        XCTAssertEqual(adapter.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0),
                                             replacementRange: unspecified), .processed)
        owner.text = "short"
        owner.revision = UUID()
        XCTAssertEqual(adapter.insertText("x", replacementRange: unspecified), .resetRequired)
        view.postsFrameChangedNotifications = true
        var observed = false
        let observer = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification,
                                                               object: view, queue: nil) { _ in
            guard !observed else { return }
            observed = true
            XCTAssertEqual(view.content.string, "short")
            XCTAssertEqual(owner.text, "short")
            XCTAssertNotNil(owner.activeLease)
            XCTAssertNil(view.claimInputMutation())
            owner.text = "newest"
            owner.revision = UUID()
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        XCTAssertEqual(adapter.reconstructWithoutInputContext(), .resetRequired)
        XCTAssertTrue(observed)
        XCTAssertEqual(owner.text, "newest")
        XCTAssertEqual(owner.undoCount, 0)
        XCTAssertFalse(adapter.disconnectAfterQuiescing())
        scheduler.runAll()
        XCTAssertEqual(resets, 1)
        XCTAssertEqual(adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertEqual(view.content.string, "newest")
        XCTAssertEqual(owner.text, "newest")
        XCTAssertTrue(adapter.disconnectAfterQuiescing())
    }

    func testStaleCapturedSnapshotDoesNotReplaceProvisionalView() throws {
        let owner = FakeEventOwner(text: "abc")
        let scheduler = EventScheduler()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(view: view, owner: owner, scheduler: scheduler) {}
        XCTAssertEqual(adapter.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0),
                                             replacementRange: unspecified), .processed)
        owner.text = "newer"
        owner.revision = UUID()
        // Deliberately violate the reservation after capturing its snapshot.
        owner.onReconstruction = { owner.text = "newest"; owner.revision = UUID() }
        XCTAssertEqual(adapter.reconstructWithoutInputContext(), .resetRequired)
        XCTAssertEqual(view.content.string, "にabc")
        XCTAssertEqual(owner.text, "newest")
        XCTAssertFalse(adapter.disconnectAfterQuiescing())
        owner.onReconstruction = nil
        XCTAssertEqual(adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertEqual(view.content.string, "newest")
        XCTAssertTrue(adapter.disconnectAfterQuiescing())
    }

    func testRevisionChangeWhenReconstructionLeaseClosesRequiresRetry() throws {
        let owner = FakeEventOwner(text: "abc")
        let scheduler = EventScheduler()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(view: view, owner: owner, scheduler: scheduler) {}
        owner.text = "first"
        owner.revision = UUID()
        owner.onClose = { owner.text = "newest"; owner.revision = UUID() }
        XCTAssertEqual(adapter.reconstructWithoutInputContext(), .resetRequired)
        XCTAssertEqual(view.content.string, "first")
        XCTAssertEqual(owner.text, "newest")
        XCTAssertFalse(adapter.disconnectAfterQuiescing())
        owner.onClose = nil
        XCTAssertEqual(adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertEqual(view.content.string, "newest")
        XCTAssertTrue(adapter.disconnectAfterQuiescing())
    }

    func testNestedInputDuringReconstructionLayoutRequiresReset() throws {
        let original = String(repeating: "line\n", count: 100)
        let owner = FakeEventOwner(text: original)
        let scheduler = EventScheduler()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: original))
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 180, height: 80))
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        var resets = 0
        let adapter = try makeAdapter(view: view, owner: owner, scheduler: scheduler) { resets += 1 }
        owner.text = "short"
        owner.revision = UUID()
        view.postsFrameChangedNotifications = true
        var observed = false
        let observer = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification,
                                                               object: view, queue: nil) { _ in
            guard !observed else { return }
            observed = true
            XCTAssertEqual(adapter.insertText("nested", replacementRange: self.unspecified), .resetRequired)
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        XCTAssertEqual(adapter.reconstructWithoutInputContext(), .resetRequired)
        XCTAssertTrue(observed)
        XCTAssertEqual(view.content.string, "short")
        XCTAssertEqual(owner.text, "short")
        XCTAssertEqual(owner.undoCount, 0)
        scheduler.runAll()
        XCTAssertEqual(resets, 1)
        XCTAssertEqual(adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertTrue(adapter.disconnectAfterQuiescing())
    }

    func testEmptySnapshotCanReplaceAndClearComposition() throws {
        let owner = FakeEventOwner(text: "abc")
        let scheduler = EventScheduler()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(view: view, owner: owner, scheduler: scheduler) {}
        XCTAssertEqual(adapter.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0),
                                             replacementRange: unspecified), .processed)
        owner.text = ""
        owner.revision = UUID()
        XCTAssertEqual(adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertEqual(view.content.string, "")
        XCTAssertEqual(owner.undoCount, 0)
        XCTAssertTrue(adapter.disconnectAfterQuiescing())
    }

    func testAcceptedCallbackRunsBeforeLeaseIsClosed() throws {
        let owner = FakeEventOwner(text: "abc")
        let scheduler = EventScheduler()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(view: view, owner: owner, scheduler: scheduler) {}
        var observed = false
        XCTAssertTrue(adapter.setContentDidChange { snapshot in
            observed = true
            XCTAssertEqual(snapshot.string, owner.text)
            XCTAssertNotNil(owner.activeLease)
            XCTAssertTrue(owner.closedLeases.isEmpty)
        })
        XCTAssertEqual(adapter.insertText("X", replacementRange: unspecified), .processed)
        XCTAssertTrue(observed)
        XCTAssertEqual(owner.closedLeases, owner.startedLeases)
        XCTAssertTrue(adapter.disconnectAfterQuiescing())
    }

    func testRevisionChangeDuringCloseRequiresResetBeforeMoreInput() throws {
        let owner = FakeEventOwner(text: "abc")
        let scheduler = EventScheduler()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        var resets = 0
        let adapter = try makeAdapter(view: view, owner: owner, scheduler: scheduler) { resets += 1 }
        owner.onClose = { owner.text = "newer"; owner.revision = UUID() }
        XCTAssertEqual(adapter.insertText("X", replacementRange: unspecified), .resetRequired)
        XCTAssertEqual(view.content.string, "Xabc")
        XCTAssertEqual(owner.text, "newer")
        XCTAssertEqual(adapter.insertText("Y", replacementRange: unspecified), .resetRequired)
        XCTAssertEqual(owner.startedLeases.count, 1)
        scheduler.runAll()
        XCTAssertEqual(resets, 1)
        XCTAssertFalse(adapter.disconnectAfterQuiescing())
        owner.onClose = nil
        XCTAssertEqual(adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertTrue(adapter.disconnectAfterQuiescing())
    }

    func testNestedInputFromTypingProviderDoesNotPublishOuterEdit() throws {
        let owner = FakeEventOwner(text: "abc")
        let scheduler = EventScheduler()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        var adapter: PreparedInputEventAdapter?
        weak var weakAdapter: PreparedInputEventAdapter?
        adapter = PreparedInputEventAdapter(view: view, snapshot: view.content, initialRevision: owner.revision,
                                            documentRevision: { owner.revision }, typingAttributes: {
            XCTAssertNotNil(owner.activeLease)
            XCTAssertEqual(weakAdapter?.insertText("nested", replacementRange: self.unspecified), .resetRequired)
            return [:]
        }, beginEvent: { owner.begin($0) }, beginReconstruction: { owner.beginReconstruction() },
           requestReset: {}, schedule: scheduler.enqueue)
        weakAdapter = adapter
        XCTAssertEqual(try XCTUnwrap(adapter).insertText("X", replacementRange: unspecified), .resetRequired)
        XCTAssertEqual(owner.text, "abc")
        XCTAssertEqual(view.content.string, "abc")
        XCTAssertTrue(owner.prepareLeases.isEmpty)
        XCTAssertEqual(owner.closedLeases, owner.startedLeases)
        XCTAssertEqual(scheduler.count, 1)
        XCTAssertTrue(try XCTUnwrap(adapter).disconnectAfterQuiescing())
        adapter = nil
    }

    func testLayoutConflictReconcilesUnderTheOriginalReservation() throws {
        let original = String(repeating: "line\n", count: 100)
        let owner = FakeEventOwner(text: original)
        let scheduler = EventScheduler()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: original))
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 180, height: 80))
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        let adapter = try makeAdapter(view: view, owner: owner, scheduler: scheduler) {}
        view.postsFrameChangedNotifications = true
        var observed = false
        let observer = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification,
                                                               object: view, queue: nil) { _ in
            guard !observed else { return }
            observed = true
            XCTAssertEqual(owner.text, "short")
            XCTAssertEqual(view.content.string, "short")
            XCTAssertNotNil(owner.activeLease)
            owner.text = "newer"
            owner.revision = UUID()
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        XCTAssertEqual(adapter.insertText("short", replacementRange: NSRange(location: 0, length: original.utf16.count)), .resetRequired)
        XCTAssertTrue(observed)
        XCTAssertEqual(owner.text, "newer")
        XCTAssertEqual(owner.undoCount, 0)
        XCTAssertEqual(owner.reconciledPhases, [.beforeFinish])
        XCTAssertEqual(owner.closedLeases, owner.startedLeases)
        XCTAssertFalse(adapter.disconnectAfterQuiescing())
        XCTAssertEqual(adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertTrue(adapter.disconnectAfterQuiescing())
    }

    func testNestedMutationDuringFinishRequiresDeferredResetAfterCommittedEdit() throws {
        let owner = FakeEventOwner(text: "abc")
        let scheduler = EventScheduler()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        var resets = 0
        var adapter: PreparedInputEventAdapter?
        adapter = try makeAdapter(view: view, owner: owner, scheduler: scheduler) { resets += 1 }
        weak let weakAdapter = adapter
        owner.onFinish = {
            XCTAssertNotNil(owner.activeLease)
            XCTAssertEqual(weakAdapter?.insertText("nested", replacementRange: self.unspecified), .resetRequired)
        }

        // The outer edit has already published even though a nested rejection
        // makes the adapter require reconstruction.
        XCTAssertEqual(try XCTUnwrap(adapter).insertText("X", replacementRange: unspecified), .resetRequired)
        XCTAssertEqual(owner.text, "Xabc")
        XCTAssertEqual(view.content.string, owner.text)
        XCTAssertEqual(owner.undoCount, 1)
        XCTAssertEqual(owner.startedLeases.count, 1)
        XCTAssertEqual(owner.closedLeases, owner.startedLeases)
        XCTAssertEqual(resets, 0)
        XCTAssertEqual(scheduler.count, 1)
        XCTAssertEqual(try XCTUnwrap(adapter).insertText("later", replacementRange: unspecified), .resetRequired)
        XCTAssertEqual(owner.startedLeases.count, 1)
        scheduler.runAll()
        XCTAssertEqual(resets, 1)
        XCTAssertTrue(try XCTUnwrap(adapter).disconnectAfterQuiescing())
        owner.onFinish = nil
        adapter = nil
    }

    func testStaleReservationDoesNotEnterSessionAndQueuedResetIsInertAfterDisconnect() throws {
        let owner = FakeEventOwner(text: "abc")
        let scheduler = EventScheduler()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        var resets = 0
        let adapter = try makeAdapter(view: view, owner: owner, scheduler: scheduler) { resets += 1 }
        owner.rejectAsStale = true

        XCTAssertEqual(adapter.insertText("X", replacementRange: unspecified), .resetRequired)
        XCTAssertEqual(view.content.string, "abc")
        XCTAssertEqual(owner.text, "abc")
        XCTAssertTrue(owner.startedLeases.isEmpty)
        XCTAssertTrue(owner.closedLeases.isEmpty)
        XCTAssertEqual(scheduler.count, 1)
        XCTAssertTrue(adapter.disconnectAfterQuiescing())
        scheduler.runAll()
        XCTAssertEqual(resets, 0)
        let newPermit = try XCTUnwrap(view.claimInputMutation())
        XCTAssertTrue(view.releaseInputMutation(newPermit))
    }

    func testRevisionAdvanceAfterReservationClosesLeaseAndDoesNotPublishStaleInput() throws {
        let owner = FakeEventOwner(text: "abc")
        let scheduler = EventScheduler()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        var resets = 0
        let adapter = try makeAdapter(view: view, owner: owner, scheduler: scheduler) { resets += 1 }
        // Deliberately violate the gate to exercise the adapter's revision check.
        owner.onBegin = { owner.text = "newer"; owner.revision = UUID() }

        XCTAssertEqual(adapter.insertText("X", replacementRange: unspecified), .resetRequired)
        XCTAssertEqual(owner.text, "newer")
        XCTAssertEqual(view.content.string, "abc")
        XCTAssertEqual(owner.closedLeases, owner.startedLeases)
        XCTAssertTrue(owner.prepareLeases.isEmpty)
        XCTAssertEqual(scheduler.count, 1)
        scheduler.runAll()
        XCTAssertEqual(resets, 1)
        XCTAssertFalse(adapter.disconnectAfterQuiescing())
        owner.onBegin = nil
        XCTAssertEqual(adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertEqual(view.content.string, "newer")
        XCTAssertTrue(adapter.disconnectAfterQuiescing())
    }

    func testQueriesRejectStaleDocumentAndReportMarkedState() throws {
        let owner = FakeEventOwner(text: "abc")
        let scheduler = EventScheduler()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(view: view, owner: owner, scheduler: scheduler) {}
        XCTAssertEqual(adapter.selectedRangeForInput(), NSRange(location: 0, length: 0))
        XCTAssertFalse(adapter.needsInputReset)
        XCTAssertEqual(adapter.markedRangeForInput().location, NSNotFound)
        XCTAssertEqual(adapter.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0),
                                             replacementRange: unspecified), .processed)
        XCTAssertEqual(adapter.markedRangeForInput(), NSRange(location: 0, length: 1))
        var actual = unspecified
        XCTAssertEqual(adapter.attributedSubstringForInput(range: NSRange(location: 0, length: 1), actualRange: &actual)?.string, "に")
        XCTAssertEqual(actual, NSRange(location: 0, length: 1))
        owner.text = "newer"
        owner.revision = UUID()
        actual = NSRange(location: 0, length: 1)
        XCTAssertNil(adapter.attributedSubstringForInput(range: NSRange(location: 0, length: 1), actualRange: &actual))
        XCTAssertTrue(adapter.needsInputReset)
        XCTAssertEqual(actual.location, NSNotFound)
        XCTAssertEqual(adapter.selectedRangeForInput().location, NSNotFound)
        XCTAssertEqual(adapter.markedRangeForInput().location, NSNotFound)
        XCTAssertEqual(adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertFalse(adapter.needsInputReset)
        XCTAssertEqual(adapter.selectedRangeForInput(), NSRange(location: 0, length: 0))
        XCTAssertTrue(adapter.disconnectAfterQuiescing())
    }

    func testGeometryQueryRejectsReentrantMutationAndLifecycleChanges() throws {
        let owner = FakeEventOwner(text: "abc")
        let scheduler = EventScheduler()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        var adapter: PreparedInputEventAdapter?
        weak var weakAdapter: PreparedInputEventAdapter?
        var nestedOutcome: PreparedInputEventAdapter.Outcome?
        var nestedReconstruction: PreparedInputEventAdapter.Outcome?
        var nestedDisconnect = true
        adapter = PreparedInputEventAdapter(view: view, snapshot: view.content, initialRevision: owner.revision,
                                            documentRevision: { owner.revision }, typingAttributes: { [:] },
                                            beginEvent: { owner.begin($0) },
                                            beginReconstruction: { owner.beginReconstruction() }, requestReset: {},
                                            rectProvider: { range, _ in
            nestedOutcome = weakAdapter?.insertText("x", replacementRange: NSRange(location: NSNotFound, length: 0))
            nestedReconstruction = weakAdapter?.reconstructWithoutInputContext()
            nestedDisconnect = weakAdapter?.disconnectAfterQuiescing() ?? true
            return (NSRect(x: 1, y: 2, width: 3, height: 4), range)
        }, schedule: scheduler.enqueue)
        weakAdapter = adapter
        let input = try XCTUnwrap(adapter)
        var actual = NSRange(location: 0, length: 0)
        XCTAssertEqual(input.firstRectForInput(range: actual, actualRange: &actual), .zero)
        XCTAssertEqual(actual.location, NSNotFound)
        XCTAssertEqual(nestedOutcome, .resetRequired)
        XCTAssertEqual(nestedReconstruction, .resetRequired)
        XCTAssertFalse(nestedDisconnect)
        XCTAssertEqual(owner.text, "abc")
        XCTAssertTrue(owner.startedLeases.isEmpty)
        XCTAssertEqual(scheduler.count, 1)
        XCTAssertEqual(input.reconstructWithoutInputContext(), .processed)
        XCTAssertTrue(input.disconnectAfterQuiescing())
        adapter = nil
    }

    func testGeometryQueryChecksRevisionAfterProviderCallout() throws {
        let owner = FakeEventOwner(text: "abc")
        let scheduler = EventScheduler()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try XCTUnwrap(PreparedInputEventAdapter(view: view, snapshot: view.content,
            initialRevision: owner.revision, documentRevision: { owner.revision }, typingAttributes: { [:] },
            beginEvent: { owner.begin($0) }, beginReconstruction: { owner.beginReconstruction() },
            requestReset: {}, indexProvider: { _, _ in
                owner.text = "newer"
                owner.revision = UUID()
                return 1
            }, schedule: scheduler.enqueue))
        XCTAssertEqual(adapter.characterIndexForInput(point: .zero), NSNotFound)
        XCTAssertEqual(adapter.selectedRangeForInput().location, NSNotFound)
        XCTAssertEqual(scheduler.count, 1)
        XCTAssertEqual(adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertTrue(adapter.disconnectAfterQuiescing())
    }

    func testContextOwnershipUsesIdentityAndBlocksReconstructionAndDisconnect() throws {
        let owner = FakeEventOwner(text: "abc")
        let scheduler = EventScheduler()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(view: view, owner: owner, scheduler: scheduler) {}
        let otherOwner = FakeEventOwner(text: "other")
        let otherView = ReadOnlyDocumentView(content: NSAttributedString(string: otherOwner.text))
        let other = try makeAdapter(view: otherView, owner: otherOwner, scheduler: scheduler) {}
        XCTAssertTrue(adapter.ownsInputView(view))
        XCTAssertFalse(adapter.ownsInputView(otherView))
        let token = try XCTUnwrap(adapter.claimInputContext())
        let otherToken = try XCTUnwrap(other.claimInputContext())
        XCTAssertNil(adapter.claimInputContext())
        XCTAssertFalse(adapter.releaseInputContext(otherToken))
        XCTAssertEqual(adapter.reconstructWithoutInputContext(), .unavailable)
        XCTAssertFalse(adapter.disconnectAfterQuiescing())
        XCTAssertTrue(adapter.releaseInputContext(token))
        XCTAssertFalse(adapter.releaseInputContext(token))
        XCTAssertEqual(adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertTrue(adapter.disconnectAfterQuiescing())
        XCTAssertTrue(other.releaseInputContext(otherToken))
        XCTAssertTrue(other.disconnectAfterQuiescing())
    }

    func testLifecycleRevisionCalloutsCannotReenterOrDrainIdleWork() throws {
        for disconnecting in [false, true] {
            let owner = FakeEventOwner(text: "abc")
            let scheduler = EventScheduler()
            let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
            weak var weakAdapter: PreparedInputEventAdapter?
            var onRevision: (() -> Void)?
            let adapter = try XCTUnwrap(PreparedInputEventAdapter(view: view, snapshot: view.content,
                initialRevision: owner.revision, documentRevision: {
                    onRevision?()
                    return owner.revision
                }, typingAttributes: { [:] }, beginEvent: { owner.begin($0) },
                beginReconstruction: { owner.beginReconstruction() }, requestReset: {}, schedule: scheduler.enqueue))
            weakAdapter = adapter
            var idleRuns = 0
            adapter.whenInputActivityIdle { idleRuns += 1 }
            var callbackRan = false
            onRevision = {
                onRevision = nil
                callbackRan = true
                XCTAssertNil(weakAdapter?.claimInputContext())
                XCTAssertFalse(weakAdapter?.disconnectAfterQuiescing() ?? true)
                XCTAssertEqual(weakAdapter?.reconstructWithoutInputContext(), .unavailable)
                XCTAssertEqual(weakAdapter?.insertText("nested", replacementRange: self.unspecified), .unavailable)
                XCTAssertEqual(weakAdapter?.selectedRangeForInput().location, NSNotFound)
                scheduler.runAll()
                XCTAssertEqual(idleRuns, 0)
            }
            if disconnecting {
                XCTAssertTrue(adapter.disconnectAfterQuiescing())
            } else {
                let token = try XCTUnwrap(adapter.claimInputContext())
                XCTAssertNil(adapter.claimInputContext())
                XCTAssertTrue(adapter.releaseInputContext(token))
            }
            XCTAssertTrue(callbackRan)
            XCTAssertEqual(idleRuns, 0)
            scheduler.runAll()
            XCTAssertEqual(idleRuns, 1)
            XCTAssertEqual(owner.text, "abc")
            if !disconnecting { XCTAssertTrue(adapter.disconnectAfterQuiescing()) }
            let permit = try XCTUnwrap(view.claimInputMutation())
            XCTAssertTrue(view.releaseInputMutation(permit))
        }
    }

    func testQueryRevisionCalloutBlocksLifecycleChangesAndIdleWork() throws {
        let owner = FakeEventOwner(text: "abc")
        let scheduler = EventScheduler()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        weak var weakAdapter: PreparedInputEventAdapter?
        var onRevision: (() -> Void)?
        let adapter = try XCTUnwrap(PreparedInputEventAdapter(view: view, snapshot: view.content,
            initialRevision: owner.revision, documentRevision: {
                onRevision?()
                return owner.revision
            }, typingAttributes: { [:] }, beginEvent: { owner.begin($0) },
            beginReconstruction: { owner.beginReconstruction() }, requestReset: {}, schedule: scheduler.enqueue))
        weakAdapter = adapter
        var idleRuns = 0
        adapter.whenInputActivityIdle { idleRuns += 1 }
        var callbackRan = false
        onRevision = {
            onRevision = nil
            callbackRan = true
            XCTAssertNil(weakAdapter?.claimInputContext())
            XCTAssertFalse(weakAdapter?.disconnectAfterQuiescing() ?? true)
            scheduler.runAll()
            XCTAssertEqual(idleRuns, 0)
        }
        XCTAssertEqual(adapter.selectedRangeForInput(), NSRange(location: 0, length: 0))
        XCTAssertTrue(callbackRan)
        XCTAssertEqual(idleRuns, 0)
        scheduler.runAll()
        XCTAssertEqual(idleRuns, 1)
        XCTAssertTrue(adapter.disconnectAfterQuiescing())
    }

    func testUnexpectedContextReleaseWaitsForQueryAndCannotReleaseNewerToken() throws {
        let owner = FakeEventOwner(text: "abc")
        let scheduler = EventScheduler()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        weak var weakAdapter: PreparedInputEventAdapter?
        var token: PreparedInputEventAdapter.InputContextToken?
        let adapter = try XCTUnwrap(PreparedInputEventAdapter(view: view, snapshot: view.content,
            initialRevision: owner.revision, documentRevision: { owner.revision }, typingAttributes: { [:] },
            beginEvent: { owner.begin($0) }, beginReconstruction: { owner.beginReconstruction() }, requestReset: {},
            rectProvider: { range, _ in
                guard let token = token, let adapter = weakAdapter else { return nil }
                XCTAssertTrue(adapter.releaseInputContextWhenIdle(token))
                XCTAssertFalse(adapter.releaseInputContext(token))
                XCTAssertNil(adapter.claimInputContext())
                return (NSRect(x: 1, y: 2, width: 3, height: 4), range)
            }, schedule: scheduler.enqueue))
        weakAdapter = adapter
        token = try XCTUnwrap(adapter.claimInputContext())
        var actual = NSRange(location: NSNotFound, length: 0)
        XCTAssertEqual(adapter.firstRectForInput(range: NSRange(location: 0, length: 0), actualRange: &actual),
                       NSRect(x: 1, y: 2, width: 3, height: 4))
        XCTAssertNil(adapter.claimInputContext())
        let oldToken = try XCTUnwrap(token)
        XCTAssertTrue(adapter.releaseInputContext(oldToken))
        let newToken = try XCTUnwrap(adapter.claimInputContext())
        scheduler.runAll()
        XCTAssertNil(adapter.claimInputContext())
        XCTAssertFalse(adapter.releaseInputContextWhenIdle(oldToken))
        XCTAssertTrue(adapter.releaseInputContext(newToken))
        XCTAssertTrue(adapter.disconnectAfterQuiescing())
    }

    func testUnexpectedContextReleaseWaitsForMutationWithoutPolling() throws {
        let owner = FakeEventOwner(text: "abc")
        let scheduler = EventScheduler()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(view: view, owner: owner, scheduler: scheduler) {}
        let token = try XCTUnwrap(adapter.claimInputContext())
        weak let weakAdapter = adapter
        owner.onFinish = {
            XCTAssertTrue(weakAdapter?.releaseInputContextWhenIdle(token) ?? false)
            XCTAssertEqual(scheduler.count, 0)
            XCTAssertFalse(weakAdapter?.releaseInputContext(token) ?? true)
        }
        XCTAssertEqual(adapter.insertText("x", replacementRange: unspecified), .processed)
        XCTAssertEqual(scheduler.count, 1)
        XCTAssertNil(adapter.claimInputContext())
        scheduler.runAll()
        let next = try XCTUnwrap(adapter.claimInputContext())
        XCTAssertTrue(adapter.releaseInputContext(next))
        XCTAssertTrue(adapter.disconnectAfterQuiescing())
        owner.onFinish = nil
    }

    func testIdleWorkRechecksNestedQueryWithoutPollingOrDoubleExecution() throws {
        let owner = FakeEventOwner(text: "abc")
        let scheduler = EventScheduler()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        weak var weakAdapter: PreparedInputEventAdapter?
        var runs = 0
        let adapter = try XCTUnwrap(PreparedInputEventAdapter(view: view, snapshot: view.content,
            initialRevision: owner.revision, documentRevision: { owner.revision }, typingAttributes: { [:] },
            beginEvent: { owner.begin($0) }, beginReconstruction: { owner.beginReconstruction() }, requestReset: {},
            indexProvider: { _, _ in
                weakAdapter?.whenInputActivityIdle { runs += 1 }
                // A previously queued drain runs in this nested event loop.
                scheduler.runAll()
                XCTAssertEqual(runs, 0)
                XCTAssertEqual(scheduler.count, 0)
                return 1
            }, schedule: scheduler.enqueue))
        weakAdapter = adapter
        adapter.whenInputActivityIdle { runs += 1 }
        XCTAssertEqual(runs, 0)
        XCTAssertEqual(adapter.characterIndexForInput(point: .zero), 1)
        XCTAssertEqual(runs, 0)
        XCTAssertEqual(scheduler.count, 1)
        scheduler.runAll()
        XCTAssertEqual(runs, 2)
        scheduler.runAll()
        XCTAssertEqual(runs, 2)
        XCTAssertTrue(adapter.disconnectAfterQuiescing())
    }

    func testIdleWorkFromMutationRunsOnlyAfterMutationReturns() throws {
        let owner = FakeEventOwner(text: "abc")
        let scheduler = EventScheduler()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(view: view, owner: owner, scheduler: scheduler) {}
        weak let weakAdapter = adapter
        var runs = 0
        owner.onFinish = {
            weakAdapter?.whenInputActivityIdle { runs += 1 }
            scheduler.runAll()
            XCTAssertEqual(runs, 0)
            XCTAssertEqual(scheduler.count, 0)
        }
        XCTAssertEqual(adapter.insertText("x", replacementRange: unspecified), .processed)
        XCTAssertEqual(runs, 0)
        XCTAssertEqual(scheduler.count, 1)
        scheduler.runAll()
        XCTAssertEqual(runs, 1)
        XCTAssertTrue(adapter.disconnectAfterQuiescing())
        owner.onFinish = nil
    }

    func testIdleCleanupBlocksNestedInputAndLifecycleButCanReleaseContext() throws {
        let owner = FakeEventOwner(text: "abc")
        let scheduler = EventScheduler()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text))
        let adapter = try makeAdapter(view: view, owner: owner, scheduler: scheduler) {}
        let token = try XCTUnwrap(adapter.claimInputContext())
        var runs = 0
        adapter.whenInputActivityIdle {
            runs += 1
            XCTAssertEqual(adapter.insertText("x", replacementRange: NSRange(location: NSNotFound, length: 0)), .unavailable)
            XCTAssertEqual(adapter.selectedRangeForInput().location, NSNotFound)
            XCTAssertEqual(adapter.reconstructWithoutInputContext(), .unavailable)
            XCTAssertFalse(adapter.disconnectAfterQuiescing())
            XCTAssertTrue(adapter.releaseInputContext(token))
            XCTAssertNil(adapter.claimInputContext())
        }
        scheduler.runAll()
        XCTAssertEqual(runs, 1)
        XCTAssertEqual(owner.text, "abc")
        XCTAssertTrue(owner.startedLeases.isEmpty)
        let next = try XCTUnwrap(adapter.claimInputContext())
        XCTAssertTrue(adapter.releaseInputContext(next))
        XCTAssertTrue(adapter.disconnectAfterQuiescing())
    }

    private func makeAdapter(view: ReadOnlyDocumentView, owner: FakeEventOwner,
                             scheduler: EventScheduler, reset: @escaping () -> Void) throws -> PreparedInputEventAdapter {
        try XCTUnwrap(PreparedInputEventAdapter(view: view, snapshot: view.content,
                                               initialRevision: owner.revision,
                                               documentRevision: { owner.revision },
                                               typingAttributes: { [:] },
                                               beginEvent: { owner.begin($0) },
                                               beginReconstruction: { owner.beginReconstruction() },
                                               requestReset: reset, schedule: scheduler.enqueue))
    }
}

private final class FakeEventOwner {
    var text: String
    var revision = UUID()
    var activeLease: UUID?
    var startedLeases: [UUID] = []
    var closedLeases: [UUID] = []
    var prepareLeases: [UUID] = []
    var publishLeases: [UUID] = []
    var finishLeases: [UUID] = []
    var undoCount = 0
    var reconciledPhases: [DocumentInputSession.PublicationConflictPhase] = []
    var rejectAsStale = false
    var onBegin: (() -> Void)?
    var onFinish: (() -> Void)?
    var onClose: (() -> Void)?
    var onReconstruction: (() -> Void)?

    init(text: String) { self.text = text }

    func beginReconstruction() -> PreparedInputEventAdapter.ReconstructionStart {
        guard activeLease == nil else { return .busy }
        let id = UUID()
        activeLease = id
        startedLeases.append(id)
        let lease = PreparedInputEventAdapter.ReconstructionReservation(
            snapshot: NSAttributedString(string: text), revision: revision, close: { [self] in
                XCTAssertEqual(activeLease, id)
                closedLeases.append(id)
                activeLease = nil
                onClose?()
            })
        onReconstruction?()
        return .reserved(lease)
    }

    func begin(_ expected: UUID) -> PreparedInputEventAdapter.ReservationResult {
        guard !rejectAsStale, expected == revision else { return .stale }
        guard activeLease == nil else { return .busy }
        let id = UUID()
        activeLease = id
        startedLeases.append(id)
        onBegin?()
        return .reserved(.init(prepare: { [self] candidate in
            XCTAssertEqual(activeLease, id)
            prepareLeases.append(id)
            let accepted = candidate.string
            return .init(publish: { [self] in
                XCTAssertEqual(activeLease, id)
                publishLeases.append(id)
                text = accepted
                revision = UUID()
            }, finish: { [self] in
                XCTAssertEqual(activeLease, id)
                finishLeases.append(id)
                undoCount += 1
                onFinish?()
            }, reconcile: { [self] phase in
                XCTAssertEqual(activeLease, id)
                reconciledPhases.append(phase)
            })
        }, close: { [self] in
            XCTAssertEqual(activeLease, id)
            closedLeases.append(id)
            activeLease = nil
            onClose?()
        }))
    }
}

private final class EventScheduler {
    private var pending: [() -> Void] = []
    var count: Int { pending.count }
    func enqueue(_ work: @escaping () -> Void) { pending.append(work) }
    func runAll() {
        while !pending.isEmpty { pending.removeFirst()() }
    }
}
#endif
