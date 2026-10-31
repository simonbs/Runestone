#if canImport(AppKit)
import AppKit
import RunestoneEngine
@testable import RunestoneAppKit
import XCTest

final class ViewportLayoutCoordinatorTests: XCTestCase {
    private let font = NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)

    func testMeasuringPredecessorPreservesVisibleAnchor() throws {
        let longLine = String(repeating: "wrapped words ", count: 40)
        let manager = LineManager(stringView: StringView(string: longLine + "\nanchor\ntail"))
        manager.rebuild()
        let coordinator = makeCoordinator(manager, width: 100)
        let anchor = manager.line(atRow: 1)
        let initial = try XCTUnwrap(coordinator.layout(in: CGRect(x: 0, y: anchor.yPosition + 10, width: 100, height: 20)))
        let oldY = anchor.yPosition
        let result = try XCTUnwrap(coordinator.layout(in: initial.viewport.offsetBy(dx: 0, dy: -5)))
        XCTAssertGreaterThan(anchor.yPosition, oldY)
        XCTAssertEqual(result.contentOffsetAdjustmentY, anchor.yPosition - oldY, accuracy: 0.001)
        XCTAssertTrue(result.lines.contains { $0.line === anchor })
        for line in result.lines {
            for placement in line.placements {
                XCTAssertEqual(placement.frame.minY, line.line.yPosition + placement.fragment.yPosition, accuracy: 0.001)
            }
        }
    }

    func testCompletedPredecessorWithChangedIndexedHeightIsRemeasured() throws {
        let manager = LineManager(stringView: StringView(string: "preceding\nanchor\ntail"))
        manager.estimatedLineHeight = 16
        manager.rebuild()
        let first = manager.firstLine
        let controller = LogicalLineLayoutController(manager: manager, line: first)
        XCTAssertTrue(controller.prepare(NSAttributedString(string: "preceding\n", attributes: [.font: font]),
                                         width: 120, fallbackHeight: 16))
        _ = controller.layout(.toLocation(first.data.length))
        XCTAssertTrue(controller.isFinishedTypesetting)
        let measuredHeight = first.data.lineHeight
        manager.setHeight(of: first, to: measuredHeight + 100)
        XCTAssertFalse(controller.hasCurrentFinishedHeight)
        var controllers = [first.id: controller]
        let coordinator = ViewportLayoutCoordinator(manager: manager, cachedControllerForLine: { line in
            controllers[line.id]
        }) { [font] line in
            if let known = controllers[line.id] { return known }
            let next = LogicalLineLayoutController(manager: manager, line: line)
            let range = NSRange(location: line.location, length: line.data.totalLength)
            let text = manager.stringView.string.substring(with: range)
            guard next.prepare(NSAttributedString(string: text, attributes: [.font: font]),
                               width: 120, fallbackHeight: 16) else { return nil }
            controllers[line.id] = next
            return next
        }
        let anchor = manager.line(atRow: 1)
        let oldY = anchor.yPosition
        let budget = try XCTUnwrap(PreparedInputViewportWorkBudget(clock: { 0 }, timeLimit: 0.016))
        let result = try XCTUnwrap(coordinator.layout(in: CGRect(x: 0, y: oldY, width: 120, height: 40), budget: budget))
        XCTAssertTrue(result.isComplete)
        XCTAssertFalse(budget.exhausted)
        XCTAssertEqual(first.data.lineHeight, measuredHeight, accuracy: 0.001)
        XCTAssertEqual(result.contentOffsetAdjustmentY, anchor.yPosition - oldY, accuracy: 0.001)
        XCTAssertTrue(controller.hasCurrentFinishedHeight)
    }

    func testFinishedPredecessorHonorsTightCoordinatorBudget() throws {
        let manager = LineManager(stringView: StringView(string: "first\nanchor\ntail"))
        manager.estimatedLineHeight = 16
        manager.rebuild()
        let first = manager.firstLine
        let controller = LogicalLineLayoutController(manager: manager, line: first)
        XCTAssertTrue(controller.prepare(NSAttributedString(string: "first\n", attributes: [.font: font]),
                                         width: 120, fallbackHeight: 16))
        _ = controller.layout(.toLocation(first.data.length))
        XCTAssertTrue(controller.hasCurrentFinishedHeight)
        var controllers = [first.id: controller]
        var cacheChecks = 0
        let coordinator = ViewportLayoutCoordinator(manager: manager, cachedControllerForLine: { _ in
            cacheChecks += 1
            return nil
        }) { [font] line in
            if let known = controllers[line.id] { return known }
            let next = LogicalLineLayoutController(manager: manager, line: line)
            let range = NSRange(location: line.location, length: line.data.totalLength)
            let text = manager.stringView.string.substring(with: range)
            guard next.prepare(NSAttributedString(string: text, attributes: [.font: font]),
                               width: 120, fallbackHeight: 16) else { return nil }
            controllers[line.id] = next
            return next
        }
        let anchor = manager.line(atRow: 1)
        let viewport = CGRect(x: 0, y: anchor.yPosition + 1, width: 120, height: 8)
        let budget = try XCTUnwrap(PreparedInputViewportWorkBudget(clock: { 0 }, timeLimit: 0.016, operationLimit: 3))
        let result = try XCTUnwrap(coordinator.layout(in: viewport, budget: budget))
        XCTAssertTrue(result.isComplete)
        XCTAssertFalse(budget.exhausted)
        XCTAssertTrue(result.lines.contains { $0.line === anchor })
        XCTAssertEqual(cacheChecks, 1)

        let tooSmall = try XCTUnwrap(PreparedInputViewportWorkBudget(clock: { 0 }, timeLimit: 0.016, operationLimit: 2))
        let refused = try XCTUnwrap(coordinator.layout(in: viewport, budget: tooSmall))
        XCTAssertFalse(refused.isComplete)
        XCTAssertTrue(tooSmall.exhausted)
    }

    func testCachedFinishedPredecessorAvoidsPreparationCharge() throws {
        let manager = LineManager(stringView: StringView(string: "first\nanchor\ntail"))
        manager.estimatedLineHeight = 16
        manager.rebuild()
        let first = manager.firstLine
        let controller = LogicalLineLayoutController(manager: manager, line: first)
        XCTAssertTrue(controller.prepare(NSAttributedString(string: "first\n", attributes: [.font: font]),
                                         width: 120, fallbackHeight: 16))
        _ = controller.layout(.toLocation(first.data.length))
        XCTAssertTrue(controller.hasCurrentFinishedHeight)
        var controllers = [first.id: controller]
        var checks = 0
        let coordinator = ViewportLayoutCoordinator(manager: manager, cachedControllerForLine: { line in
            checks += 1
            return controllers[line.id]
        }) { [font] line in
            if let known = controllers[line.id] { return known }
            let next = LogicalLineLayoutController(manager: manager, line: line)
            let range = NSRange(location: line.location, length: line.data.totalLength)
            let text = manager.stringView.string.substring(with: range)
            guard next.prepare(NSAttributedString(string: text, attributes: [.font: font]),
                               width: 120, fallbackHeight: 16) else { return nil }
            controllers[line.id] = next
            return next
        }
        let anchor = manager.line(atRow: 1)
        let viewport = CGRect(x: 0, y: anchor.yPosition + 1, width: 120, height: 8)
        let budget = try XCTUnwrap(PreparedInputViewportWorkBudget(clock: { 0 }, timeLimit: 0.016, operationLimit: 2))
        let result = try XCTUnwrap(coordinator.layout(in: viewport, budget: budget))
        XCTAssertTrue(result.isComplete)
        XCTAssertFalse(budget.exhausted)
        XCTAssertEqual(checks, 1)
        XCTAssertTrue(result.lines.contains { $0.line === anchor })

        // The ordinary non-budgeted path does not use the fast lookup.
        let oldChecks = checks
        XCTAssertTrue(try XCTUnwrap(coordinator.layout(in: viewport)).isComplete)
        XCTAssertEqual(checks, oldChecks)
    }

    func testCachedPredecessorChecksAreIndependentlyBounded() throws {
        let manager = LineManager(stringView: StringView(string: String(repeating: "line\n", count: 100)))
        manager.estimatedLineHeight = 16
        manager.rebuild()
        var controllers: [DocumentLineNodeID: LogicalLineLayoutController] = [:]
        for row in 0..<30 {
            let line = manager.line(atRow: row)
            let controller = LogicalLineLayoutController(manager: manager, line: line)
            let range = NSRange(location: line.location, length: line.data.totalLength)
            let text = manager.stringView.string.substring(with: range)
            XCTAssertTrue(controller.prepare(NSAttributedString(string: text, attributes: [.font: font]),
                                             width: 120, fallbackHeight: 16))
            _ = controller.layout(.toLocation(line.data.length))
            XCTAssertTrue(controller.hasCurrentFinishedHeight)
            controllers[line.id] = controller
        }
        var checks = 0
        var providers = 0
        let coordinator = ViewportLayoutCoordinator(manager: manager, cachedControllerForLine: { line in
            checks += 1
            return controllers[line.id]
        }) { line in
            providers += 1
            return controllers[line.id]
        }
        let anchor = manager.line(atRow: 25)
        let viewport = CGRect(x: 0, y: anchor.yPosition, width: 120, height: 600)
        let budget = try XCTUnwrap(PreparedInputViewportWorkBudget(clock: { 0 }, timeLimit: 0.016, operationLimit: 1))
        let result = try XCTUnwrap(coordinator.layout(in: viewport, budget: budget))
        XCTAssertFalse(result.isComplete)
        XCTAssertTrue(budget.exhausted)
        XCTAssertEqual(checks, 16)
        XCTAssertEqual(providers, 1)
    }

    func testFailedPreparationStillReturnsAccumulatedAnchorAdjustment() throws {
        let manager = LineManager(stringView: StringView(string: "first\nsecond\nanchor\ntail"))
        manager.rebuild()
        var controllers: [DocumentLineNodeID: LogicalLineLayoutController] = [:]
        let failedLine = manager.firstLine
        let coordinator = ViewportLayoutCoordinator(manager: manager) { [font] line in
            if line === failedLine { return nil }
            if let controller = controllers[line.id] { return controller }
            let controller = LogicalLineLayoutController(manager: manager, line: line)
            let text = manager.stringView.string.substring(with: NSRange(location: line.location, length: line.data.totalLength))
            guard controller.prepare(NSAttributedString(string: text, attributes: [.font: font]), width: 100, fallbackHeight: 16) else { return nil }
            controllers[line.id] = controller
            return controller
        }
        let anchor = manager.line(atRow: 2)
        let initial = try XCTUnwrap(coordinator.layout(in: CGRect(x: 0, y: anchor.yPosition + 10, width: 100, height: 20)))
        XCTAssertTrue(initial.isComplete)
        let oldY = anchor.yPosition
        let requested = CGRect(x: 0, y: initial.viewport.minY - 30, width: 100, height: 60)
        let result = try XCTUnwrap(coordinator.layout(in: requested))
        XCTAssertFalse(result.isComplete)
        XCTAssertTrue(result.lines.isEmpty)
        XCTAssertGreaterThan(anchor.yPosition, oldY)
        XCTAssertEqual(result.contentOffsetAdjustmentY, anchor.yPosition - oldY, accuracy: 0.001)
    }

    func testShrinkingEstimatedTailReturnsCorrectedVisiblePlacements() throws {
        let manager = LineManager(stringView: StringView(string: "short"))
        manager.rebuild()
        let line = manager.firstLine
        let controller = LogicalLineLayoutController(manager: manager, line: line)
        XCTAssertTrue(controller.prepare(NSAttributedString(string: "short", attributes: [.font: font]), width: 100, fallbackHeight: 16))
        manager.setHeight(of: line, to: 500)
        let coordinator = ViewportLayoutCoordinator(manager: manager) { _ in controller }
        let result = try XCTUnwrap(coordinator.layout(in: CGRect(x: 0, y: 400, width: 100, height: 40)))
        XCTAssertLessThan(result.viewport.minY, 400)
        XCTAssertEqual(result.contentOffsetAdjustmentY, result.viewport.minY - 400, accuracy: 0.001)
        let placement = try XCTUnwrap(result.lines.first?.placements.first)
        XCTAssertGreaterThan(placement.frame.maxY, result.viewport.minY)
        XCTAssertLessThan(placement.frame.minY, result.viewport.maxY)
    }

    func testDisjointJumpDoesNotMeasureDocumentPrefix() throws {
        let text = (0..<200).map { "line \($0)" }.joined(separator: "\n")
        let manager = LineManager(stringView: StringView(string: text))
        manager.rebuild()
        let coordinator = makeCoordinator(manager, width: 100)
        let untouched = manager.line(atRow: 50)
        let originalHeight = untouched.data.lineHeight
        let target = manager.line(atRow: 180)
        let result = try XCTUnwrap(coordinator.layout(in: CGRect(x: 0, y: target.yPosition, width: 100, height: 40)))
        XCTAssertTrue(result.lines.contains { $0.line === target })
        XCTAssertEqual(untouched.data.lineHeight, originalHeight, accuracy: 0.001)
    }

    func testLargeDocumentDistantViewportPreparesOnlyNearbyLines() throws {
        // Building the line index is deliberately outside this measurement:
        // its full-document cost is a separate contract from viewport layout.
        let lineCount = 25_000
        let manager = LineManager(stringView: StringView(string: String(repeating: "short line\n", count: lineCount)))
        manager.estimatedLineHeight = 16
        manager.rebuild()
        var requests: [Int] = []
        var controllers: [DocumentLineNodeID: LogicalLineLayoutController] = [:]
        let coordinator = ViewportLayoutCoordinator(manager: manager) { [font] line in
            requests.append(line.index)
            if let controller = controllers[line.id] { return controller }
            let controller = LogicalLineLayoutController(manager: manager, line: line)
            let range = NSRange(location: line.location, length: line.data.totalLength)
            let text = manager.stringView.string.substring(with: range)
            guard controller.prepare(NSAttributedString(string: text, attributes: [.font: font]),
                                     width: 240, fallbackHeight: 16) else { return nil }
            controllers[line.id] = controller
            return controller
        }

        for row in [24_000, 12_000] {
            requests.removeAll()
            let target = manager.line(atRow: row)
            let viewport = CGRect(x: 0, y: target.yPosition, width: 240, height: 80)
            let result = try XCTUnwrap(coordinator.layout(in: viewport))
            XCTAssertTrue(result.isComplete)
            XCTAssertTrue(result.lines.contains { $0.line === target }, "Distant target must be laid out")
            let prepared = Set(requests)
            // At 16 points estimated height the viewport spans five short
            // lines; allow space for predecessor correction and height changes.
            XCTAssertLessThanOrEqual(requests.count, 16, "A viewport jump must not repeatedly prepare distant lines")
            XCTAssertLessThanOrEqual(prepared.count, 16, "A viewport jump must not prepare the document prefix")
            XCTAssertTrue(prepared.allSatisfy { $0 >= row - 8 && $0 <= row + 8 },
                          "Preparation should stay near the requested viewport: \(prepared.sorted())")
        }
    }

    private func makeCoordinator(_ manager: LineManager, width: CGFloat) -> ViewportLayoutCoordinator {
        var controllers: [DocumentLineNodeID: LogicalLineLayoutController] = [:]
        return ViewportLayoutCoordinator(manager: manager) { [font] line in
            if let controller = controllers[line.id] { return controller }
            let controller = LogicalLineLayoutController(manager: manager, line: line)
            let text = manager.stringView.string.substring(with: NSRange(location: line.location, length: line.data.totalLength))
            guard controller.prepare(NSAttributedString(string: text, attributes: [.font: font]), width: width, fallbackHeight: 16) else { return nil }
            controllers[line.id] = controller
            return controller
        }
    }
}
#endif
