#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class PreparedInputResponderMovementIntegrationTests: XCTestCase {
    func testSuccessiveVerticalMovesRetainPreferredVisualColumn() throws {
        let fixture = try MovementIntegrationFixture("abcdef\nx\n\nabcdef")
        try fixture.setSelection(NSRange(location: 5, length: 0))
        let starts = fixture.host.parentStarts
        let children = fixture.host.childStarts
        for location in [8, 9, 15] {
            XCTAssertTrue(fixture.send("moveDown:"))
            XCTAssertEqual(fixture.selection, NSRange(location: location, length: 0))
        }
        XCTAssertFalse(fixture.window.isKeyWindow)
        XCTAssertEqual(fixture.host.parentStarts - starts, 3)
        XCTAssertEqual(fixture.host.parentCloses, fixture.host.parentStarts)
        XCTAssertEqual(fixture.host.childStarts - children, 3)
        XCTAssertEqual(fixture.host.childCloses, fixture.host.childStarts)
        XCTAssertEqual(fixture.host.completions.suffix(3).map(\.outcome), [.completed, .completed, .completed])
        XCTAssertEqual(fixture.host.text, "abcdef\nx\n\nabcdef")
        fixture.disconnect()
    }

    func testVerticalMovementRequestsFreshViewportAtTheVisibleEdge() throws {
        let fixture = try MovementIntegrationFixture(String(repeating: "abcdef\n", count: 50))
        try fixture.setSelection(NSRange(location: 3, length: 0))
        let before = fixture.scroll.contentView.bounds.minY
        for line in 1...15 {
            XCTAssertTrue(fixture.send("moveDown:"))
            XCTAssertEqual(fixture.selection, NSRange(location: line * 7 + 3, length: 0), "line \(line)")
        }
        XCTAssertGreaterThan(fixture.scroll.contentView.bounds.minY, before)
        XCTAssertEqual(fixture.view.visibleLayout?.viewport, fixture.scroll.contentView.bounds)
        XCTAssertEqual(fixture.host.parentStarts, fixture.host.parentCloses)
        XCTAssertEqual(fixture.host.childStarts, fixture.host.childCloses)
        fixture.disconnect()
    }

    func testVerticalSelectionExtensionRetainsFixedAnchorWhenDirectionReverses() throws {
        let fixture = try MovementIntegrationFixture("abcdef\nx\n\nabcdef")
        try fixture.setSelection(NSRange(location: 5, length: 0))
        for (command, expected) in [
            ("moveDownAndModifySelection:", NSRange(location: 5, length: 3)),
            ("moveDownAndModifySelection:", NSRange(location: 5, length: 4)),
            ("moveUpAndModifySelection:", NSRange(location: 5, length: 3)),
            ("moveUpAndModifySelection:", NSRange(location: 5, length: 0))
        ] {
            XCTAssertTrue(fixture.send(command))
            XCTAssertEqual(fixture.selection, expected, command)
        }
        XCTAssertEqual(fixture.host.childStarts, fixture.host.childCloses)
        XCTAssertEqual(fixture.host.parentStarts, fixture.host.parentCloses)
        XCTAssertEqual(fixture.host.text, "abcdef\nx\n\nabcdef")
        fixture.disconnect()
    }

    func testLineAndHorizontalCommandsUseCurrentRevisionAndChildGate() throws {
        let fixture = try MovementIntegrationFixture("ab\r\ncd")
        try fixture.setSelection(NSRange(location: 1, length: 0))
        let starts = fixture.host.childStarts
        for (command, expected) in [
            ("moveToBeginningOfLine:", 0),
            ("moveRight:", 1),
            ("moveToEndOfLine:", 2),
            ("moveRight:", 4),
            ("moveLeft:", 2)
        ] {
            XCTAssertTrue(fixture.send(command))
            XCTAssertEqual(fixture.selection, NSRange(location: expected, length: 0), command)
        }
        XCTAssertEqual(fixture.host.childStarts - starts, 5)
        XCTAssertEqual(fixture.host.childStarts, fixture.host.childCloses)
        XCTAssertEqual(fixture.host.parentStarts, fixture.host.parentCloses)
        XCTAssertEqual(Array(fixture.host.text.utf8), Array("ab\r\ncd".utf8))
        XCTAssertEqual(fixture.host.preparations, 0)
        fixture.disconnect()
    }

    func testDirectStandardSelectorReusesAnActiveDispatchReservation() throws {
        let fixture = try MovementIntegrationFixture("abc")
        XCTAssertTrue(fixture.view.responds(to: NSSelectorFromString("moveForward:")))
        XCTAssertTrue(fixture.view.responds(to: NSSelectorFromString("copy:")))
        let parents = fixture.host.parentStarts
        let children = fixture.host.childStarts
        XCTAssertTrue(fixture.connection.performCoordinatedInput {
            fixture.view.performStandardCommand("moveForward:", on: fixture.connection, hasFocus: { true })
        })
        XCTAssertEqual(fixture.selection, NSRange(location: 1, length: 0))
        XCTAssertEqual(fixture.host.parentStarts - parents, 1)
        XCTAssertEqual(fixture.host.childStarts - children, 1)
        XCTAssertEqual(fixture.host.completions.last?.outcome, .completed)
        fixture.disconnect()
    }

    func testVisualWordMovementAndExtensionRouteThroughTheDocumentGate() throws {
        let fixture = try MovementIntegrationFixture("one, two!")
        try fixture.setSelection(NSRange(location: 0, length: 0))
        let parents = fixture.host.parentStarts
        let children = fixture.host.childStarts
        for (command, expected) in [
            ("moveWordRight:", NSRange(location: 3, length: 0)),
            ("moveWordRight:", NSRange(location: 8, length: 0)),
            ("moveWordLeft:", NSRange(location: 5, length: 0)),
            ("moveWordLeftAndModifySelection:", NSRange(location: 0, length: 5)),
            ("moveWordRightAndModifySelection:", NSRange(location: 3, length: 2)),
            ("moveWordRightAndModifySelection:", NSRange(location: 5, length: 3))
        ] {
            XCTAssertTrue(fixture.send(command))
            XCTAssertEqual(fixture.selection, expected, command)
        }
        XCTAssertEqual(fixture.host.parentStarts - parents, 6)
        XCTAssertEqual(fixture.host.childStarts - children, 6)
        XCTAssertEqual(fixture.host.parentStarts, fixture.host.parentCloses)
        XCTAssertEqual(fixture.host.childStarts, fixture.host.childCloses)
        XCTAssertEqual(fixture.host.completions.suffix(6).map(\.outcome),
                       [.completed, .completed, .completed, .completed, .completed, .completed])
        XCTAssertEqual(fixture.host.preparations, 0)
        XCTAssertEqual(fixture.host.text, "one, two!")
        fixture.disconnect()
    }

    func testChangedViewportRejectsMovementInsteadOfUsingOldGeometry() throws {
        let fixture = try MovementIntegrationFixture("abcdef\nx\nabcdef")
        try fixture.setSelection(NSRange(location: 5, length: 0))
        let originalBounds = fixture.scroll.contentView.bounds
        let originalLayout = try XCTUnwrap(fixture.view.visibleLayout)
        XCTAssertEqual(originalBounds, originalLayout.viewport)
        let pasteboard = MovementNoPasteboard()
        func allowed(_ name: String) -> Bool {
            fixture.view.canPerformEditingAction(NSSelectorFromString(name), connection: fixture.connection,
                adapter: fixture.attachment.adapter, pasteboard: pasteboard)
        }
        XCTAssertTrue(allowed("moveDown:"))
        XCTAssertFalse(allowed("transpose:"))
        fixture.scroll.contentView.postsBoundsChangedNotifications = false
        fixture.scroll.contentView.setBoundsSize(NSSize(width: originalBounds.width - 30, height: originalBounds.height))
        XCTAssertNotEqual(fixture.scroll.contentView.bounds, originalLayout.viewport)
        XCTAssertFalse(allowed("moveDown:"))
        let children = fixture.host.childStarts
        XCTAssertTrue(fixture.send("moveDown:"))
        XCTAssertEqual(fixture.selection, NSRange(location: 5, length: 0))
        XCTAssertEqual(fixture.host.childStarts, children)
        XCTAssertEqual(fixture.connection.takeInputFailures().records,
                       [.init(operation: .command, failure: .init(reason: .unavailable, effect: .notApplied))])
        XCTAssertEqual(fixture.host.completions.last?.outcome, .mayHaveApplied)
        fixture.scroll.contentView.setBoundsSize(originalBounds.size)
        fixture.scroll.contentView.postsBoundsChangedNotifications = true
        fixture.view.updateViewport()
        fixture.disconnect()
    }

    func testStaleRevisionRejectsMovementBeforeAnOldSelectionCanBeApplied() throws {
        let fixture = try MovementIntegrationFixture("abcdef\nxyz")
        try fixture.setSelection(NSRange(location: 3, length: 0))
        let children = fixture.host.childStarts
        fixture.host.inputRevision = UUID()
        XCTAssertFalse(fixture.send("moveDown:"))
        XCTAssertEqual(fixture.host.childStarts, children)
        XCTAssertEqual(fixture.host.completions.last?.outcome, .rejectedBeforeAdmission(.stale))
        XCTAssertEqual(fixture.view.content.string, "abcdef\nxyz")
        XCTAssertEqual(fixture.attachment.adapter.selectedRangeForInput().location, NSNotFound)
        fixture.queue.runAll()
        XCTAssertEqual(fixture.view.content.string, "abcdef\nxyz")
        fixture.disconnect()
    }

    func testPointerDragCrossesItsFixedAnchorAndClampsOutsideViewport() throws {
        let fixture = try MovementIntegrationFixture("abcdef\nxyz")
        XCTAssertTrue(try fixture.beginPointer(at: 3))
        XCTAssertEqual(fixture.selection, NSRange(location: 3, length: 0))
        XCTAssertTrue(try fixture.continuePointer(at: 5))
        XCTAssertEqual(fixture.selection, NSRange(location: 3, length: 2))
        XCTAssertTrue(try fixture.continuePointer(at: 1))
        XCTAssertEqual(fixture.selection, NSRange(location: 1, length: 2))

        let inside = try fixture.screenPoint(at: 5)
        let viewport = try XCTUnwrap(fixture.view.visibleLayout?.viewport)
        let screenViewport = fixture.window.convertToScreen(fixture.view.convert(viewport, to: nil))
        XCTAssertTrue(fixture.continuePointer(atScreen: NSPoint(x: screenViewport.maxX + 1000, y: inside.y)))
        XCTAssertEqual(fixture.selection, NSRange(location: 3, length: 3))
        XCTAssertTrue(fixture.continuePointer(atScreen: NSPoint(x: screenViewport.minX - 1000, y: inside.y)))
        XCTAssertEqual(fixture.selection, NSRange(location: 0, length: 3))
        XCTAssertEqual(fixture.host.parentStarts, fixture.host.parentCloses)
        XCTAssertEqual(fixture.host.childStarts, fixture.host.childCloses)
        XCTAssertEqual(fixture.host.preparations, 0)
        XCTAssertEqual(fixture.host.text, "abcdef\nxyz")
        fixture.disconnect()
    }

    func testPointerGateRejectionAndFocusLossDoNotReplayGesture() throws {
        let fixture = try MovementIntegrationFixture("abcdef\nxyz")
        XCTAssertTrue(try fixture.beginPointer(at: 2))
        let target = try fixture.screenPoint(at: 5)
        let children = fixture.host.childStarts
        fixture.host.externallyBusy = true
        XCTAssertFalse(fixture.continuePointer(atScreen: target))
        XCTAssertEqual(fixture.host.completions.last?.outcome, .rejectedBeforeAdmission(.busy))
        XCTAssertEqual(fixture.host.childStarts, children)
        fixture.host.externallyBusy = false
        fixture.queue.runAll()
        XCTAssertEqual(fixture.selection, NSRange(location: 2, length: 0))

        XCTAssertTrue(fixture.continuePointer(atScreen: target, hasFocus: false))
        XCTAssertEqual(fixture.selection, NSRange(location: 2, length: 0))
        XCTAssertTrue(fixture.continuePointer(atScreen: target)) // A new callback cannot revive the lost gesture.
        XCTAssertEqual(fixture.selection, NSRange(location: 2, length: 0))
        XCTAssertEqual(fixture.connection.takeInputFailures().records.map(\.failure.reason), [.unavailable, .unavailable])
        XCTAssertEqual(fixture.host.childStarts, children)
        fixture.view.disarmForDetachment()
        XCTAssertTrue(fixture.continuePointer(atScreen: target))
        XCTAssertEqual(fixture.selection, NSRange(location: 2, length: 0))
        fixture.disconnect()
    }

    func testPointerDragRejectsStaleDocumentRevisionWithoutReplay() throws {
        let fixture = try MovementIntegrationFixture("abcdef\nxyz")
        XCTAssertTrue(try fixture.beginPointer(at: 2))
        let target = try fixture.screenPoint(at: 5)
        let children = fixture.host.childStarts
        fixture.host.inputRevision = UUID()
        XCTAssertFalse(fixture.continuePointer(atScreen: target))
        XCTAssertEqual(fixture.host.completions.last?.outcome, .rejectedBeforeAdmission(.stale))
        XCTAssertEqual(fixture.host.childStarts, children)
        XCTAssertEqual(fixture.view.content.string, "abcdef\nxyz")
        fixture.queue.runAll()
        XCTAssertEqual(fixture.host.childStarts, children)
        XCTAssertEqual(fixture.view.content.string, "abcdef\nxyz")
        fixture.disconnect()
    }

    func testPointerAutoscrollAdvancesAcrossFreshViewportsAndStopsAtBudget() throws {
        let fixture = try MovementIntegrationFixture((0..<50).map { "line \($0) abcdef" }.joined(separator: "\n"))
        let scheduler = MovementAutoscrollScheduler()
        let clock = PreparedInputAutoscrollClock(maximumFrames: 2, now: { scheduler.time },
                                                  enqueue: scheduler.enqueue) { [weak view = fixture.view] point in
            view?.performPointerAutoscrollStep(at: point, hasFocus: { true }) ?? false
        }
        fixture.view.installPointerAutoscrollClock(clock)
        XCTAssertTrue(try fixture.beginPointer(at: 0))
        let viewport = try XCTUnwrap(fixture.view.visibleLayout?.viewport)
        let screenViewport = fixture.window.convertToScreen(fixture.view.convert(viewport, to: nil))
        let outside = NSPoint(x: screenViewport.midX, y: screenViewport.minY - 48)
        XCTAssertTrue(fixture.continuePointer(atScreen: outside))
        let before = fixture.selection
        let initialY = fixture.scroll.contentView.bounds.minY
        XCTAssertEqual(scheduler.pendingCount, 1)
        scheduler.fireNext()
        XCTAssertGreaterThan(fixture.scroll.contentView.bounds.minY, initialY)
        XCTAssertGreaterThan(fixture.selection.length, before.length)
        XCTAssertEqual(scheduler.pendingCount, 1)
        scheduler.fireNext()
        XCTAssertEqual(scheduler.pendingCount, 0)
        let afterBudget = fixture.scroll.contentView.bounds.minY
        XCTAssertTrue(fixture.continuePointer(atScreen: outside))
        XCTAssertEqual(scheduler.pendingCount, 0)
        XCTAssertEqual(fixture.scroll.contentView.bounds.minY, afterBudget)
        XCTAssertEqual(fixture.host.parentStarts, fixture.host.parentCloses)
        XCTAssertEqual(fixture.host.childStarts, fixture.host.childCloses)
        fixture.disconnect()
    }

    func testPointerAutoscrollMovesUpAndKeepsCRLFAndUnicodeBoundaries() throws {
        let text = Array(repeating: "A👨‍👩‍👧‍👦e\u{301}Z\r\n", count: 50).joined()
        let fixture = try MovementIntegrationFixture(text)
        let scheduler = MovementAutoscrollScheduler()
        let clock = PreparedInputAutoscrollClock(now: { scheduler.time }, enqueue: scheduler.enqueue) { [weak view = fixture.view] point in
            view?.performPointerAutoscrollStep(at: point, hasFocus: { true }) ?? false
        }
        fixture.view.installPointerAutoscrollClock(clock)
        // Prepare the intervening rows using overlapping viewports, so their
        // measured Unicode line heights are known before the upward gesture.
        // Each scroll can queue a follow-up layout when estimates change.
        for y in [CGFloat(64), 128, 192, 220] {
            fixture.scroll.contentView.scroll(to: NSPoint(x: 0, y: y))
            fixture.scroll.reflectScrolledClipView(fixture.scroll.contentView)
            fixture.view.updateViewport()
            let viewportReady = expectation(for: NSPredicate { _, _ in
                PreparedInputViewportStep.perform(in: fixture.view, dx: 0, dy: 0,
                                                  clock: { 0 }, isCurrent: { true }) == .boundary
            }, evaluatedWith: nil)
            XCTAssertEqual(XCTWaiter().wait(for: [viewportReady], timeout: 2), .completed)
        }
        let viewport = try XCTUnwrap(fixture.view.visibleLayout?.viewport)
        let screenViewport = fixture.window.convertToScreen(fixture.view.convert(viewport, to: nil))
        let center = NSPoint(x: screenViewport.midX, y: screenViewport.midY)
        XCTAssertTrue(fixture.connection.performCoordinatedInput {
            fixture.view.beginPointerSelection(at: center, extending: false, connection: fixture.connection, hasFocus: { true })
        })
        let anchor = fixture.selection.location
        XCTAssertNotEqual(anchor, NSNotFound)
        let outside = NSPoint(x: screenViewport.midX, y: screenViewport.maxY + 48)
        XCTAssertTrue(fixture.continuePointer(atScreen: outside))
        let before = fixture.selection
        let initialY = fixture.scroll.contentView.bounds.minY
        XCTAssertGreaterThan(initialY, 0)
        XCTAssertEqual(scheduler.pendingCount, 1)
        scheduler.fireNext()
        let actualY = fixture.scroll.contentView.bounds.minY
        let edgeOffset = InputScreenRangeGeometry.characterIndexForDrag(for: outside, in: fixture.view)
        let failures = fixture.connection.takeInputFailures().records
        let diagnostic = "initialY=\(initialY), actualY=\(actualY), proposedY=\(initialY - 48), " +
            "layout=\(String(describing: fixture.view.visibleLayout?.viewport)), " +
            "edgeOffset=\(String(describing: edgeOffset)), pending=\(scheduler.pendingCount), " +
            "failures=\(failures), completion=\(String(describing: fixture.host.completions.last?.outcome))"
        XCTAssertLessThan(actualY, initialY, diagnostic)
        XCTAssertLessThan(fixture.selection.location, before.location, diagnostic)
        XCTAssertEqual(fixture.selection.upperBound, anchor)
        XCTAssertTrue(PreparedInputCommandInterpreter.isValidBoundary(fixture.selection.location, in: text as NSString))
        XCTAssertTrue(PreparedInputCommandInterpreter.isValidBoundary(fixture.selection.upperBound, in: text as NSString))
        let selected = (text as NSString).substring(with: fixture.selection)
        XCTAssertTrue(selected.contains("\r\n"))
        XCTAssertTrue(selected.contains("👨‍👩‍👧‍👦"))
        XCTAssertEqual(fixture.host.text, text)
        fixture.disconnect()
    }

    func testPointerAutoscrollStopsAtBothHorizontalBoundaries() throws {
        for right in [false, true] {
            let fixture = try MovementIntegrationFixture((0..<30).map { "line \($0) abcdef" }.joined(separator: "\n"))
            let scheduler = MovementAutoscrollScheduler()
            let clock = PreparedInputAutoscrollClock(now: { scheduler.time }, enqueue: scheduler.enqueue) { [weak view = fixture.view] point in
                view?.performPointerAutoscrollStep(at: point, hasFocus: { true }) ?? false
            }
            fixture.view.installPointerAutoscrollClock(clock)
            XCTAssertTrue(try fixture.beginPointer(at: 2))
            let inside = try fixture.screenPoint(at: 2)
            let viewport = try XCTUnwrap(fixture.view.visibleLayout?.viewport)
            let screenViewport = fixture.window.convertToScreen(fixture.view.convert(viewport, to: nil))
            let x = right ? screenViewport.maxX + 48 : screenViewport.minX - 48
            XCTAssertTrue(fixture.continuePointer(atScreen: NSPoint(x: x, y: inside.y)))
            let before = fixture.selection
            let initialBounds = fixture.scroll.contentView.bounds
            XCTAssertEqual(scheduler.pendingCount, 1)
            scheduler.fireNext()
            XCTAssertEqual(fixture.scroll.contentView.bounds, initialBounds)
            XCTAssertEqual(fixture.selection, before)
            XCTAssertEqual(scheduler.pendingCount, 0)
            fixture.disconnect()
        }
    }

    func testPointerReentryCancelsPendingAutoscroll() throws {
        let fixture = try MovementIntegrationFixture((0..<50).map { "line \($0) abcdef" }.joined(separator: "\n"))
        let scheduler = MovementAutoscrollScheduler()
        let clock = PreparedInputAutoscrollClock(now: { scheduler.time }, enqueue: scheduler.enqueue) { [weak view = fixture.view] point in
            view?.performPointerAutoscrollStep(at: point, hasFocus: { true }) ?? false
        }
        fixture.view.installPointerAutoscrollClock(clock)
        XCTAssertTrue(try fixture.beginPointer(at: 0))
        let inside = try fixture.screenPoint(at: 2)
        let viewport = try XCTUnwrap(fixture.view.visibleLayout?.viewport)
        let screenViewport = fixture.window.convertToScreen(fixture.view.convert(viewport, to: nil))
        let outside = NSPoint(x: screenViewport.midX, y: screenViewport.minY - 48)
        XCTAssertTrue(fixture.continuePointer(atScreen: outside))
        XCTAssertEqual(scheduler.pendingCount, 1)
        XCTAssertTrue(fixture.continuePointer(atScreen: inside))
        let selection = fixture.selection
        let bounds = fixture.scroll.contentView.bounds
        XCTAssertEqual(scheduler.pendingCount, 0)
        scheduler.fireNextEvenIfCancelled()
        XCTAssertEqual(fixture.selection, selection)
        XCTAssertEqual(fixture.scroll.contentView.bounds, bounds)
        XCTAssertTrue(fixture.continuePointer(atScreen: outside))
        XCTAssertEqual(scheduler.pendingCount, 0)
        fixture.disconnect()
    }

    func testBusyAutoscrollDoesNotBlockAnotherView() throws {
        let text = (0..<50).map { "line \($0) abcdef" }.joined(separator: "\n")
        let first = try MovementIntegrationFixture(text)
        let second = try MovementIntegrationFixture(text)
        let firstScheduler = MovementAutoscrollScheduler()
        let secondScheduler = MovementAutoscrollScheduler()
        for (fixture, scheduler) in [(first, firstScheduler), (second, secondScheduler)] {
            let clock = PreparedInputAutoscrollClock(now: { scheduler.time }, enqueue: scheduler.enqueue) { [weak view = fixture.view] point in
                view?.performPointerAutoscrollStep(at: point, hasFocus: { true }) ?? false
            }
            fixture.view.installPointerAutoscrollClock(clock)
            XCTAssertTrue(try fixture.beginPointer(at: 0))
            let viewport = try XCTUnwrap(fixture.view.visibleLayout?.viewport)
            let screenViewport = fixture.window.convertToScreen(fixture.view.convert(viewport, to: nil))
            XCTAssertTrue(fixture.continuePointer(atScreen: NSPoint(x: screenViewport.midX, y: screenViewport.minY - 48)))
        }
        let firstBounds = first.scroll.contentView.bounds
        let firstSelection = first.selection
        let secondBounds = second.scroll.contentView.bounds
        let secondSelection = second.selection
        first.host.externallyBusy = true
        firstScheduler.fireNext()
        XCTAssertEqual(first.scroll.contentView.bounds, firstBounds)
        XCTAssertEqual(first.selection, firstSelection)
        XCTAssertEqual(firstScheduler.pendingCount, 0)
        XCTAssertEqual(first.host.completions.last?.outcome, .rejectedBeforeAdmission(.busy))
        secondScheduler.fireNext()
        XCTAssertGreaterThan(second.scroll.contentView.bounds.minY, secondBounds.minY)
        XCTAssertGreaterThan(second.selection.length, secondSelection.length)
        XCTAssertEqual(second.host.parentStarts, second.host.parentCloses)
        XCTAssertEqual(second.host.childStarts, second.host.childCloses)
        first.host.externallyBusy = false
        first.disconnect()
        second.disconnect()
    }

    func testPointerAutoscrollRejectsStaleRevisionAndStopsOnFocusLoss() throws {
        for loseFocus in [false, true] {
            let fixture = try MovementIntegrationFixture((0..<50).map { "line \($0) abcdef" }.joined(separator: "\n"))
            let scheduler = MovementAutoscrollScheduler()
            var focused = true
            let clock = PreparedInputAutoscrollClock(now: { scheduler.time }, enqueue: scheduler.enqueue) { [weak view = fixture.view] point in
                view?.performPointerAutoscrollStep(at: point, hasFocus: { focused }) ?? false
            }
            fixture.view.installPointerAutoscrollClock(clock)
            XCTAssertTrue(try fixture.beginPointer(at: 0))
            let viewport = try XCTUnwrap(fixture.view.visibleLayout?.viewport)
            let screenViewport = fixture.window.convertToScreen(fixture.view.convert(viewport, to: nil))
            XCTAssertTrue(fixture.continuePointer(atScreen: NSPoint(x: screenViewport.midX, y: screenViewport.minY - 48)))
            let before = fixture.selection
            let initialY = fixture.scroll.contentView.bounds.minY
            if loseFocus { focused = false } else { fixture.host.inputRevision = UUID() }
            scheduler.fireNext()
            XCTAssertEqual(fixture.scroll.contentView.bounds.minY, initialY)
            if loseFocus { XCTAssertEqual(fixture.selection, before) }
            else { XCTAssertEqual(fixture.view.content.string, fixture.host.text) }
            XCTAssertEqual(scheduler.pendingCount, 0)
            fixture.disconnect()
        }
    }

    func testPointerAutoscrollCancelsQueuedTickOnMouseUpAndDetachment() throws {
        for detach in [false, true] {
            let fixture = try MovementIntegrationFixture((0..<50).map { "line \($0) abcdef" }.joined(separator: "\n"))
            let scheduler = MovementAutoscrollScheduler()
            let clock = PreparedInputAutoscrollClock(now: { scheduler.time }, enqueue: scheduler.enqueue) { [weak view = fixture.view] point in
                view?.performPointerAutoscrollStep(at: point, hasFocus: { true }) ?? false
            }
            fixture.view.installPointerAutoscrollClock(clock)
            XCTAssertTrue(try fixture.beginPointer(at: 0))
            let viewport = try XCTUnwrap(fixture.view.visibleLayout?.viewport)
            let screenViewport = fixture.window.convertToScreen(fixture.view.convert(viewport, to: nil))
            XCTAssertTrue(fixture.continuePointer(atScreen: NSPoint(x: screenViewport.midX, y: screenViewport.minY - 48)))
            let before = fixture.selection
            let initialY = fixture.scroll.contentView.bounds.minY
            if detach { fixture.view.disarmForDetachment() }
            else {
                let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: .zero, modifierFlags: [],
                                                              timestamp: 0, windowNumber: fixture.window.windowNumber,
                                                              context: nil, eventNumber: 0, clickCount: 1, pressure: 0))
                fixture.view.mouseUp(with: event)
            }
            scheduler.fireNextEvenIfCancelled()
            XCTAssertEqual(fixture.scroll.contentView.bounds.minY, initialY)
            XCTAssertEqual(fixture.selection, before)
            XCTAssertEqual(scheduler.pendingCount, 0)
            fixture.disconnect()
        }
    }

    func testFocusLossDuringChildAdmissionCannotApplyEditingCommands() throws {
        for command in ["moveForward:", "moveRight:", "deleteBackward:", "insertNewline:"] {
            let fixture = try MovementIntegrationFixture("abc\r\ndef")
            try fixture.setSelection(NSRange(location: 1, length: 0))
            fixture.host.onBeginChild = { fixture.connection.suspendForFocusLoss() }
            XCTAssertTrue(fixture.send(command), command)
            fixture.host.onBeginChild = nil
            XCTAssertEqual(fixture.host.text, "abc\r\ndef", command)
            XCTAssertEqual(fixture.host.preparations, 0, command)
            XCTAssertEqual(fixture.host.completions.last?.outcome, .mayHaveApplied, command)
            fixture.queue.runAll()
            XCTAssertEqual(fixture.view.content.string, "abc\r\ndef", command)
            fixture.disconnect()
        }
    }

    func testParentGateContentionDoesNotMoveOrReplaySelection() throws {
        let fixture = try MovementIntegrationFixture("abcdef\nxyz")
        try fixture.setSelection(NSRange(location: 3, length: 0))
        fixture.host.externallyBusy = true
        let children = fixture.host.childStarts
        XCTAssertFalse(fixture.send("moveDown:"))
        XCTAssertEqual(fixture.selection, NSRange(location: 3, length: 0))
        XCTAssertEqual(fixture.host.childStarts, children)
        XCTAssertEqual(fixture.host.completions.last?.outcome, .rejectedBeforeAdmission(.busy))
        fixture.host.externallyBusy = false
        fixture.queue.runAll()
        XCTAssertEqual(fixture.selection, NSRange(location: 3, length: 0))
        fixture.disconnect()
    }
}

private struct MovementNoPasteboard: PreparedInputClipboardCommand.Pasteboard {
    var hasPlainText: Bool { false }
    func readPlainText() -> String? { nil }
    func writePlainText(_ value: String) -> Bool { false }
}

private final class MovementIntegrationFixture {
    let host: MovementIntegrationHost
    let queue: MovementIntegrationQueue
    let attachment: PreparedInputDocumentAttachment
    let view: PreparedInputResponderView
    let connection: PreparedInputContextConnection
    let window: NSWindow
    let scroll: NSScrollView

    init(_ text: String) throws {
        _ = NSApplication.shared
        let host = MovementIntegrationHost(text)
        let queue = MovementIntegrationQueue()
        let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attachResponder(
            host: host, lifetime: host.lifetime, bridge: host.bridge,
            makeDriver: { MovementIntegrationDriver($0) }, schedule: queue.enqueue))
        let view = try XCTUnwrap(attachment.view as? PreparedInputResponderView)
        view.inputViewportClock = { 0 }
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 240, height: 130),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let scroll = NSScrollView(frame: try XCTUnwrap(window.contentView).bounds)
        window.contentView?.addSubview(scroll)
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        self.host = host
        self.queue = queue
        self.attachment = attachment
        self.view = view
        self.connection = attachment.connection
        self.window = window
        self.scroll = scroll
        XCTAssertFalse(window.isKeyWindow)
        XCTAssertTrue(connection.resumeForFocus())
        XCTAssertNotNil(view.visibleLayout)
    }

    var selection: NSRange { attachment.adapter.selectedRangeForInput() }

    func setSelection(_ range: NSRange) throws {
        var result: PreparedInputEventAdapter.Outcome?
        XCTAssertTrue(connection.performCoordinatedInput { result = self.attachment.adapter.setSelection(range) })
        XCTAssertEqual(try XCTUnwrap(result), .processed)
    }

    @discardableResult
    func send(_ name: String) -> Bool {
        var forwarded = false
        let admitted = connection.performCoordinatedInput {
            self.view.routeCommand(NSSelectorFromString(name), on: self.connection) { _ in
                forwarded = true
                return true
            }
        }
        XCTAssertFalse(forwarded, "\(name) must remain in the document input contract")
        return admitted
    }

    func screenPoint(at offset: Int) throws -> NSPoint {
        let rect = try XCTUnwrap(InputScreenCaretGeometry.rect(at: offset, in: view))
        return NSPoint(x: rect.midX, y: rect.midY)
    }

    func beginPointer(at offset: Int) throws -> Bool {
        let point = try screenPoint(at: offset)
        return connection.performCoordinatedInput {
            self.view.beginPointerSelection(at: point, extending: false, connection: self.connection, hasFocus: { true })
        }
    }

    func continuePointer(at offset: Int) throws -> Bool {
        continuePointer(atScreen: try screenPoint(at: offset))
    }

    func continuePointer(atScreen point: NSPoint, hasFocus: Bool = true) -> Bool {
        connection.performCoordinatedInput {
            self.view.continuePointerSelection(at: point, connection: self.connection, hasFocus: { hasFocus })
        }
    }

    func disconnect() {
        XCTAssertFalse(attachment.disconnect())
        queue.runAll()
        XCTAssertTrue(attachment.disconnect())
        window.close()
    }
}

private final class MovementIntegrationHost: RunestoneInputDispatchHost {
    let lifetime = RunestoneInputDocumentLifetime()
    let bridge = RunestoneInputDocumentBridge()
    let text: String
    var inputRevision = UUID()
    var externallyBusy = false
    var reconstructionOpen = false
    var parentOpen = false
    var childOpen = false
    var parentStarts = 0
    var parentCloses = 0
    var childStarts = 0
    var childCloses = 0
    var preparations = 0
    var completions: [RunestoneInputDispatchCompletion] = []
    var onBeginChild: (() -> Void)?

    init(_ text: String) { self.text = text }
    func beginInputEvent(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputEventStart {
        XCTFail("Selection must reserve a child through the active parent")
        return .busy
    }
    func beginInputDispatch(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputDispatchStart {
        guard !externallyBusy, !reconstructionOpen, !parentOpen else { return .busy }
        guard expectedRevision == inputRevision else { return .stale }
        parentOpen = true
        parentStarts += 1
        return .reserved(MovementIntegrationParent(self))
    }
    func beginInputReconstruction() -> RunestoneInputReconstructionStart {
        guard !externallyBusy, !reconstructionOpen, !parentOpen else { return .busy }
        reconstructionOpen = true
        return .reserved(MovementIntegrationSnapshot(self))
    }
    func typingAttributes(for source: ReadOnlyDocumentView) -> [NSAttributedString.Key: Any] {
        [.font: NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)]
    }
    func inputDispatchDidComplete(_ completion: RunestoneInputDispatchCompletion, source: ReadOnlyDocumentView) {
        XCTAssertFalse(parentOpen)
        XCTAssertFalse(childOpen)
        completions.append(completion)
    }
}

private final class MovementIntegrationParent: RunestoneInputDispatchReservation {
    let host: MovementIntegrationHost
    init(_ host: MovementIntegrationHost) { self.host = host }
    func beginInputOperation(expectedRevision: UUID) -> RunestoneInputEventStart {
        guard host.parentOpen, !host.childOpen else { return .busy }
        guard expectedRevision == host.inputRevision else { return .stale }
        host.childOpen = true
        host.childStarts += 1
        host.onBeginChild?()
        return .reserved(MovementIntegrationChild(host))
    }
    func close() {
        XCTAssertTrue(host.parentOpen)
        XCTAssertFalse(host.childOpen)
        host.parentOpen = false
        host.parentCloses += 1
    }
}

private final class MovementIntegrationChild: RunestoneInputEventReservation {
    let host: MovementIntegrationHost
    init(_ host: MovementIntegrationHost) { self.host = host }
    func prepare(candidate: NSAttributedString) -> RunestoneInputPreparedPublication? {
        host.preparations += 1
        XCTFail("Selection movement must not prepare a document change")
        return nil
    }
    func close() {
        XCTAssertTrue(host.childOpen)
        host.childOpen = false
        host.childCloses += 1
    }
}

private final class MovementIntegrationSnapshot: RunestoneInputReconstructionReservation {
    let host: MovementIntegrationHost
    let snapshot: NSAttributedString
    let revision: UUID
    init(_ host: MovementIntegrationHost) {
        self.host = host
        snapshot = NSAttributedString(string: host.text,
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)])
        revision = host.inputRevision
    }
    func close() { host.reconstructionOpen = false }
}

private final class MovementIntegrationDriver: PreparedInputContextConnection.Driver {
    let object = NSObject()
    init(_ client: NSTextInputClient) {}
    var associationTarget: NSObject { object }
    func activate() {}
    func handle(_ event: NSEvent) -> Bool { false }
    func invalidateCoordinates() {}
    func discardMarkedText() {}
    func deactivate() {}
}

private final class MovementAutoscrollScheduler {
    private final class Item {
        var cancelled = false
        let work: () -> Void
        init(_ work: @escaping () -> Void) { self.work = work }
    }
    var time: TimeInterval = 0
    private var items: [Item] = []
    var pendingCount: Int { items.filter { !$0.cancelled }.count }
    func enqueue(_ delay: TimeInterval, _ work: @escaping () -> Void) -> () -> Void {
        let item = Item(work)
        items.append(item)
        return { item.cancelled = true }
    }
    func fireNext() {
        guard !items.isEmpty else { XCTFail("Expected a scheduled tick"); return }
        let item = items.removeFirst()
        time += 1.0 / 60.0
        if !item.cancelled { item.work() }
    }
    func fireNextEvenIfCancelled() {
        guard !items.isEmpty else { XCTFail("Expected a scheduled tick"); return }
        let item = items.removeFirst()
        time += 1.0 / 60.0
        item.work()
    }
}

private final class MovementIntegrationQueue {
    private var work: [() -> Void] = []
    func enqueue(_ body: @escaping () -> Void) { work.append(body) }
    func runAll() {
        var count = 0
        while !work.isEmpty && count < 200 {
            count += 1
            work.removeFirst()()
        }
        XCTAssertTrue(work.isEmpty, "The input queue must not poll indefinitely")
    }
}
#endif
