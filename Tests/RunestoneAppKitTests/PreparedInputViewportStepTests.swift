#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class PreparedInputViewportStepTests: XCTestCase {
    func testOneStepScrollsAndPublishesCurrentViewportGeometry() throws {
        let fixture = try ViewportStepFixture(text: (0..<200).map { "line \($0)" }.joined(separator: "\n"))
        let before = fixture.scroll.contentView.bounds
        let contentRevision = fixture.view.contentRevision
        let selectionRevision = fixture.view.inputSelectionRevision
        XCTAssertEqual(PreparedInputViewportStep.perform(in: fixture.view, dx: 0, dy: 24, clock: { 0 }, isCurrent: { true }), .progressed)
        XCTAssertGreaterThan(fixture.scroll.contentView.bounds.minY, before.minY)
        XCTAssertLessThanOrEqual(fixture.scroll.contentView.bounds.minY - before.minY, 64.01)
        XCTAssertEqual(fixture.view.visibleLayout?.viewport, fixture.scroll.contentView.bounds)
        XCTAssertEqual(fixture.view.visibleLayout?.isComplete, true)
        XCTAssertEqual(fixture.view.contentRevision, contentRevision)
        XCTAssertEqual(fixture.view.inputSelectionRevision, selectionRevision)
        withExtendedLifetime(fixture.window) {}
    }

    func testAppSizedViewportCanAdvanceRepeatedlyAcrossShortLines() throws {
        // Match the app's 720x480 foreground scroll view, 100 short lines and
        // system-sized monospaced typing font, without substituting geometry.
        let fixture = try ViewportStepFixture(text: String(repeating: "abcdefghijklmno\n", count: 100),
            width: 720, height: 480, font: .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular))
        XCTAssertEqual(fixture.scroll.contentView.bounds.size, NSSize(width: 720, height: 480))
        let contentRevision = fixture.view.contentRevision
        let selectionRevision = fixture.view.inputSelectionRevision
        for step in 0..<8 {
            let before = fixture.scroll.contentView.bounds
            let outcome = PreparedInputViewportStep.perform(in: fixture.view, dx: 0, dy: 48,
                                                            clock: { 0 }, isCurrent: { true })
            XCTAssertEqual(outcome, .progressed, "viewport step \(step) at \(before)")
            guard outcome == .progressed else { return }
            XCTAssertGreaterThan(fixture.scroll.contentView.bounds.minY, before.minY)
            XCTAssertEqual(fixture.view.visibleLayout?.viewport, fixture.scroll.contentView.bounds)
            XCTAssertEqual(fixture.view.contentRevision, contentRevision)
            XCTAssertEqual(fixture.view.inputSelectionRevision, selectionRevision)
        }
        withExtendedLifetime(fixture.window) {}
    }

    func testNoProgressInvalidDeltaAndOversizedViewportAreRejected() throws {
        let fixture = try ViewportStepFixture(text: String(repeating: "line\n", count: 200))
        let before = fixture.scroll.contentView.bounds
        XCTAssertEqual(PreparedInputViewportStep.perform(in: fixture.view, dx: 0, dy: -20, clock: { 0 }, isCurrent: { true }), .boundary)
        XCTAssertEqual(PreparedInputViewportStep.perform(in: fixture.view, dx: .nan, dy: 0, isCurrent: { true }), .unavailable)
        XCTAssertEqual(PreparedInputViewportStep.perform(in: fixture.view, dx: 0, dy: 65, isCurrent: { true }), .unavailable)
        XCTAssertEqual(fixture.scroll.contentView.bounds, before)
        let oversized = try ViewportStepFixture(text: "short\nline", width: 2_100)
        let oversizedBefore = oversized.scroll.contentView.bounds
        XCTAssertEqual(PreparedInputViewportStep.perform(in: oversized.view, dx: 0, dy: 10, clock: { 0 }, isCurrent: { true }), .unavailable)
        XCTAssertEqual(oversized.scroll.contentView.bounds, oversizedBefore)
        withExtendedLifetime((fixture.window, oversized.window)) {}
    }

    func testCurrentSnapshotAndSelectionAreRecheckedBeforeScrolling() throws {
        let fixture = try ViewportStepFixture(text: String(repeating: "line\n", count: 200))
        let before = fixture.scroll.contentView.bounds
        var checks = 0
        XCTAssertEqual(PreparedInputViewportStep.perform(in: fixture.view, dx: 0, dy: 20, clock: { 0 }) {
            checks += 1
            if checks == 1 { fixture.view.invalidateInputSelectionTracking() }
            return true
        }, .unavailable)
        XCTAssertEqual(fixture.scroll.contentView.bounds, before)
        XCTAssertEqual(checks, 1)
        withExtendedLifetime(fixture.window) {}
    }

    func testBoundsCalloutInvalidatesStepWithoutRetrying() throws {
        let fixture = try ViewportStepFixture(text: String(repeating: "line\n", count: 200))
        var valid = true
        var notifications = 0
        let token = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification,
            object: fixture.scroll.contentView, queue: nil) { _ in valid = false; notifications += 1 }
        defer { NotificationCenter.default.removeObserver(token) }
        XCTAssertEqual(PreparedInputViewportStep.perform(in: fixture.view, dx: 0, dy: 20, clock: { 0 }, isCurrent: { valid }), .unavailable)
        XCTAssertGreaterThan(notifications, 0)
        let after = fixture.scroll.contentView.bounds
        XCTAssertEqual(PreparedInputViewportStep.perform(in: fixture.view, dx: 0, dy: 20, clock: { 0 }, isCurrent: { false }), .unavailable)
        XCTAssertEqual(fixture.scroll.contentView.bounds, after)
        withExtendedLifetime(fixture.window) {}
    }

    func testUnexpectedBoundsOrScreenMovementInvalidatesStep() throws {
        let movedBounds = try ViewportStepFixture(text: String(repeating: "line\n", count: 200))
        let clip = movedBounds.scroll.contentView
        var changed = false
        let boundsObserver = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification,
            object: clip, queue: nil) { _ in
                guard !changed else { return }
                changed = true
                clip.scroll(to: NSPoint(x: clip.bounds.minX, y: clip.bounds.minY + 3))
            }
        defer { NotificationCenter.default.removeObserver(boundsObserver) }
        XCTAssertEqual(PreparedInputViewportStep.perform(in: movedBounds.view, dx: 0, dy: 20,
                                                       clock: { 0 }, isCurrent: { true }), .unavailable)
        XCTAssertTrue(changed)

        let movedWindow = try ViewportStepFixture(text: String(repeating: "line\n", count: 200))
        var windowChanged = false
        let windowObserver = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification,
            object: movedWindow.scroll.contentView, queue: nil) { _ in
                guard !windowChanged else { return }
                windowChanged = true
                let origin = movedWindow.window.frame.origin
                movedWindow.window.setFrameOrigin(NSPoint(x: origin.x + 20, y: origin.y))
            }
        defer { NotificationCenter.default.removeObserver(windowObserver) }
        XCTAssertEqual(PreparedInputViewportStep.perform(in: movedWindow.view, dx: 0, dy: 20,
                                                       clock: { 0 }, isCurrent: { true }), .unavailable)
        XCTAssertTrue(windowChanged)
        withExtendedLifetime((movedBounds.window, movedWindow.window)) {}
    }

    func testDistantViewportCanStepWithoutPreparingDocumentPrefix() throws {
        let fixture = try ViewportStepFixture(text: (0..<12_000).map { "line \($0)" }.joined(separator: "\n"))
        let distant = fixture.view.manager.line(atRow: 10_000)
        fixture.scroll.contentView.scroll(to: NSPoint(x: 0, y: distant.yPosition))
        fixture.view.updateViewport()
        // Jumping into estimated layout can adjust the anchor and enqueue a
        // viewport retry. Let those passes settle before requesting new input.
        for _ in 0..<4 {
            let turn = expectation(description: "settle distant viewport")
            DispatchQueue.main.async { turn.fulfill() }
            wait(for: [turn], timeout: 2)
        }
        let before = fixture.scroll.contentView.bounds
        XCTAssertNotNil(fixture.view.visibleLayout)
        var identityChecks = 0
        XCTAssertEqual(PreparedInputViewportStep.perform(in: fixture.view, dx: 0, dy: 20, clock: { 0 }) {
            identityChecks += 1
            return true
        }, .progressed)
        XCTAssertGreaterThanOrEqual(identityChecks, 3)
        XCTAssertGreaterThan(fixture.scroll.contentView.bounds.minY, before.minY)
        XCTAssertEqual(fixture.view.visibleLayout?.viewport, fixture.scroll.contentView.bounds)
        withExtendedLifetime(fixture.window) {}
    }

    func testExpiredBudgetDoesNotScroll() throws {
        let fixture = try ViewportStepFixture(text: String(repeating: "line\n", count: 200))
        let before = fixture.scroll.contentView.bounds
        var calls = 0
        let result = PreparedInputViewportStep.perform(in: fixture.view, dx: 0, dy: 20,
            clock: { calls += 1; return calls == 1 ? 0 : 1 }, timeLimit: 0.01, isCurrent: { true })
        XCTAssertEqual(result, .unavailable)
        XCTAssertEqual(fixture.scroll.contentView.bounds, before)
        XCTAssertEqual(fixture.view.visibleLayout?.viewport, before)
        withExtendedLifetime(fixture.window) {}
    }

    func testExhaustedWorkDoesNotEscapeIntoUnboundedRetry() throws {
        var scheduled: [() -> Void] = []
        let fixture = try ViewportStepFixture(text: String(repeating: "line\n", count: 200),
                                              scheduler: { _, work in scheduled.append(work) })
        let clip = fixture.scroll.contentView
        let before = clip.bounds
        let result = PreparedInputViewportStep.perform(in: fixture.view, dx: 0, dy: 20,
            clock: { 0 }, operationLimit: 1, isCurrent: { true })
        XCTAssertEqual(result, .unavailable)
        XCTAssertNotEqual(clip.bounds, before)
        XCTAssertNil(fixture.view.visibleLayout)
        fixture.view.updateViewport()
        XCTAssertNil(fixture.view.visibleLayout)
        XCTAssertEqual(scheduled.count, 1)
        scheduled.first?()
        XCTAssertEqual(fixture.view.visibleLayout?.viewport, clip.bounds)
        XCTAssertEqual(scheduled.count, 1)
        withExtendedLifetime(fixture.window) {}
    }

    func testReentrantBoundsChangeDoesNotScheduleUnboundedRetry() throws {
        var scheduled: [() -> Void] = []
        let fixture = try ViewportStepFixture(text: String(repeating: "line\n", count: 200),
                                              scheduler: { _, work in scheduled.append(work) })
        let clip = fixture.scroll.contentView
        var reentered = false
        let result = PreparedInputViewportStep.perform(in: fixture.view, dx: 0, dy: 20,
            clock: {
                if fixture.view.updatingViewport && !reentered {
                    reentered = true
                    clip.scroll(to: NSPoint(x: clip.bounds.minX, y: clip.bounds.minY + 1))
                }
                return 0
            }, isCurrent: { true })
        XCTAssertTrue(reentered)
        XCTAssertEqual(result, .unavailable)
        XCTAssertNil(fixture.view.visibleLayout)
        fixture.view.updateViewport()
        XCTAssertNil(fixture.view.visibleLayout)
        XCTAssertEqual(scheduled.count, 1)
        scheduled.first?()
        XCTAssertEqual(fixture.view.visibleLayout?.viewport, clip.bounds)
        XCTAssertEqual(scheduled.count, 1)
        withExtendedLifetime(fixture.window) {}
    }

    func testLongNearbyLineAndRetiredViewAreRejectedBeforeScrolling() throws {
        let text = String(repeating: "short\n", count: 12) + String(repeating: "x", count: 5_000) + "\nlast"
        let fixture = try ViewportStepFixture(text: text)
        let before = fixture.scroll.contentView.bounds
        XCTAssertEqual(PreparedInputViewportStep.perform(in: fixture.view, dx: 0, dy: 20, clock: { 0 }, isCurrent: { true }), .unavailable)
        XCTAssertEqual(fixture.scroll.contentView.bounds, before)
        fixture.view.quarantineInputViewWithoutCallouts()
        XCTAssertEqual(PreparedInputViewportStep.perform(in: fixture.view, dx: 0, dy: 20, clock: { 0 }, isCurrent: { true }), .unavailable)
        XCTAssertEqual(fixture.scroll.contentView.bounds, before)
        withExtendedLifetime(fixture.window) {}
    }
}

private final class ViewportStepFixture {
    let window: NSWindow
    let scroll: NSScrollView
    let view: ReadOnlyDocumentView

    init(text: String, width: CGFloat = 180, height: CGFloat = 80,
         font: NSFont = .monospacedSystemFont(ofSize: 16, weight: .regular),
         scheduler: @escaping (TimeInterval, @escaping () -> Void) -> Void = { delay, work in
             DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
         }) throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: width, height: height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let scroll = NSScrollView(frame: window.contentView!.bounds)
        let view = ReadOnlyDocumentView(snapshot: NSAttributedString(string: text,
            attributes: [.font: font]), fallbackHeight: 16,
                                        viewportRecoveryScheduler: scheduler, viewportRecoveryClock: { 0 })
        window.contentView!.addSubview(scroll)
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        XCTAssertNotNil(view.visibleLayout)
        self.window = window
        self.scroll = scroll
        self.view = view
    }
}
#endif
