#if canImport(AppKit)
import AppKit
import RunestoneEngine
@testable import RunestoneAppKit
import XCTest

final class LogicalLineLayoutControllerTests: XCTestCase {
    private let font = NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)

    func testIncrementalWrappedLayoutUpdatesFollowingLinePosition() throws {
        let firstText = String(repeating: "café 😀 word ", count: 20) + "\r\n"
        let text = StringView(string: firstText + "last")
        let manager = LineManager(stringView: text)
        manager.rebuild()
        let first = manager.firstLine
        let following = manager.lastLine
        let controller = LogicalLineLayoutController(manager: manager, line: first)
        let input = NSAttributedString(string: firstText, attributes: [.font: font])
        XCTAssertTrue(controller.prepare(input, width: 90, fallbackHeight: 16))
        let initial = controller.layout(.toLineFragmentIndex(0))
        let firstFragment = try XCTUnwrap(initial.first)
        XCTAssertEqual(firstFragment.frame.minY, 0, accuracy: 0.001)
        let same = controller.layout(.toLineFragmentIndex(0))
        XCTAssertEqual(same.count, initial.count)
        XCTAssertEqual(same.first?.fragment.id, firstFragment.fragment.id)
        let full = controller.layout(.toLocation(input.length))
        XCTAssertGreaterThan(full.count, 2)
        let last = try XCTUnwrap(full.last)
        let viewport = CGRect(x: 0, y: last.fragment.yPosition, width: 90, height: last.frame.height)
        let visible = controller.layout(.inRect(viewport))
        XCTAssertLessThan(visible.count, full.count)
        XCTAssertEqual(visible.map { $0.fragment.id }, [last.fragment.id])
        XCTAssertTrue(visible.allSatisfy { $0.fragment.yPosition + $0.fragment.scaledSize.height > viewport.minY &&
            $0.fragment.yPosition < viewport.maxY })
        XCTAssertEqual(following.yPosition, last.frame.maxY, accuracy: 0.001)
        for placement in full {
            XCTAssertEqual(placement.documentRange.location, first.location + placement.fragment.visibleRange.location)
            XCTAssertEqual(placement.frame.minY, first.yPosition + placement.fragment.yPosition, accuracy: 0.001)
        }
        XCTAssertTrue(controller.prepare(input, width: 200, fallbackHeight: 16))
        let wider = controller.layout(.toLocation(input.length))
        XCTAssertLessThan(wider.count, full.count)
    }

    func testDrawingUsesCurrentLinePositionAfterInsertionBeforeIt() throws {
        let text = StringView(string: "head\nsecond line with some words")
        let manager = LineManager(stringView: text)
        manager.rebuild()
        let line = manager.lastLine
        let controller = LogicalLineLayoutController(manager: manager, line: line)
        let input = NSAttributedString(string: "second line with some words", attributes: [.font: font, .foregroundColor: NSColor.black])
        XCTAssertTrue(controller.prepare(input, width: 85, fallbackHeight: 12))
        let original = controller.layout(.toLocation(input.length))
        XCTAssertGreaterThan(original.count, 1)
        let oldStart = try XCTUnwrap(original.first).documentRange.location
        let oldY = line.yPosition

        text.replaceText(in: NSRange(location: 0, length: 0), with: "X\n")
        _ = manager.removeCharacters(in: NSRange(location: 0, length: 0))
        _ = manager.insert("X\n" as NSString, at: 0)
        XCTAssertTrue(manager.lastLine === line)
        XCTAssertGreaterThan(line.yPosition, oldY)
        let moved = controller.layout(.toLocation(input.length))
        XCTAssertEqual(moved.first?.documentRange.location, oldStart + 2)
        XCTAssertEqual(try XCTUnwrap(moved.first).frame.minY, line.yPosition, accuracy: 0.001)

        let width = 120
        let height = Int(ceil(try XCTUnwrap(moved.last).frame.maxY)) + 5
        func bitmap() throws -> CGContext {
            try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        }
        let actual = try bitmap()
        let reference = try bitmap()
        for context in [actual, reference] {
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
        }
        controller.draw(original, in: actual)
        for placement in original {
            reference.saveGState()
            reference.translateBy(x: 0, y: line.yPosition + placement.fragment.yPosition)
            LineFragmentRenderer.draw(placement.fragment, in: reference)
            reference.restoreGState()
        }
        func bytes(_ context: CGContext) throws -> [UInt8] {
            let data = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
            return Array(UnsafeBufferPointer(start: data, count: width * height * 4))
        }
        let pixels = try bytes(actual)
        XCTAssertTrue(stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] != 0 })
        XCTAssertEqual(pixels, try bytes(reference))
        let otherController = LogicalLineLayoutController(manager: manager, line: manager.firstLine)
        XCTAssertTrue(otherController.prepare(NSAttributedString(string: "X\n", attributes: [.font: font]),
                                              width: 85, fallbackHeight: 12))
        let foreign = try bitmap()
        otherController.draw(original, in: foreign)
        XCTAssertFalse(try bytes(foreign).contains { $0 != 0 })
        controller.invalidate()
        let cleared = try bitmap()
        controller.draw(original, in: cleared)
        XCTAssertFalse(try bytes(cleared).contains { $0 != 0 })
    }

    func testEmptyLineAndInvalidOrRemovedInputs() throws {
        let text = StringView(string: "é\n")
        let manager = LineManager(stringView: text)
        manager.rebuild()
        let first = manager.firstLine
        let trailing = manager.lastLine
        let firstController = LogicalLineLayoutController(manager: manager, line: first)
        let trailingController = LogicalLineLayoutController(manager: manager, line: trailing)
        XCTAssertFalse(firstController.prepare(NSAttributedString(string: "e\u{301}\n"), width: 100, fallbackHeight: 12))
        XCTAssertTrue(firstController.layout(.toLocation(1)).isEmpty)
        XCTAssertTrue(trailingController.prepare(NSAttributedString(string: ""), width: 100,
                                                 heightMultiplier: 1.5, fallbackHeight: 12))
        XCTAssertTrue(trailingController.layout(.toLocation(0)).isEmpty)
        XCTAssertEqual(trailing.data.lineHeight, 18, accuracy: 0.001)
        let range = NSRange(location: 1, length: 1)
        text.replaceText(in: range, with: "")
        _ = manager.removeCharacters(in: range)
        _ = manager.insert("" as NSString, at: range.location)
        XCTAssertTrue(trailingController.layout(.toLocation(0)).isEmpty)
        XCTAssertFalse(trailingController.prepare(NSAttributedString(string: ""), width: 100, fallbackHeight: 12))
        firstController.invalidate()
        XCTAssertTrue(firstController.prepare(NSAttributedString(string: "é", attributes: [.font: font]),
                                              width: 100, fallbackHeight: 12))
        XCTAssertEqual(firstController.layout(.toLocation(1)).first?.documentRange, NSRange(location: 0, length: 1))
    }
}
#endif
