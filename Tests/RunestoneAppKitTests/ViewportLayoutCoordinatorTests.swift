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
