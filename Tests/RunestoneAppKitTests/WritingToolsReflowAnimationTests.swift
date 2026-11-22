#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

/// Pure geometry and offscreen cleanup; no window is created or activated.
final class WritingToolsReflowAnimationTests: XCTestCase {
    func testNativeClockProgressMovesTrailingTextBetweenOldAndNewLayout() {
        let old = CGRect(x: 20, y: 40, width: 180, height: 90)
        let new = CGRect(x: 30, y: 80, width: 170, height: 120)
        let layout = WritingToolsReflowFrame(old: old, new: new)
        let start = layout.presentation(at: 0)
        XCTAssertEqual(start.old, old)
        XCTAssertEqual(start.new.origin, old.origin)
        XCTAssertEqual(start.progress, 0)
        let halfway = layout.presentation(at: 0.5)
        XCTAssertEqual(halfway.old.origin, CGPoint(x: 25, y: 60))
        XCTAssertEqual(halfway.new.origin, halfway.old.origin)
        XCTAssertEqual(halfway.old.size, old.size)
        XCTAssertEqual(halfway.new.size, new.size)
        let end = layout.presentation(at: 1)
        XCTAssertEqual(end.new, new)
        XCTAssertEqual(end.old.origin, new.origin)
        XCTAssertEqual(end.progress, 1)
    }

    func testOutOfRangeAndInvalidProgressCannotLeaveStaleGeometry() {
        let layout = WritingToolsReflowFrame(old: CGRect(x: 0, y: 0, width: 20, height: 10),
                                             new: CGRect(x: 0, y: 30, width: 20, height: 40))
        XCTAssertEqual(layout.presentation(at: -1).progress, 0)
        XCTAssertEqual(layout.presentation(at: 2).progress, 1)
        XCTAssertEqual(layout.presentation(at: .nan).new, layout.new)
        XCTAssertEqual(layout.presentation(at: .infinity).new, layout.new)
    }

    func testUnrenderableAndCancelledAnimationsLeaveCanonicalTextUntouched() throws {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "Original prose\nTrailing text"))
        let revision = view.contentRevision
        let bitmap = try XCTUnwrap(CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let preview = NSTextPreview(snapshotImage: try XCTUnwrap(bitmap.makeImage()),
                                    presentationFrame: CGRect(x: 0, y: 0, width: 2, height: 2))
        let animation = RunestoneWritingToolsReflowAnimation(editor: view, before: preview)
        animation.start(after: NSRange(location: 15, length: 13))
        animation.updateProgress(0.5)
        animation.finish()
        animation.finish()
        animation.updateProgress(0)
        XCTAssertNil(view.writingToolsReflowHiddenRange)
        XCTAssertNil(view.writingToolsReflowAnimation)
        XCTAssertEqual(view.content.string, "Original prose\nTrailing text")
        XCTAssertEqual(view.contentRevision, revision)
    }
}
#endif
