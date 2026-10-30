@testable import Runestone
import XCTest

final class TreeSitterSyntaxHighlightMapperTests: XCTestCase {
    func testMapsCaptureNamesAndRangesRelativeToRequestedText() {
        let request = ByteRange(location: 20, length: 20)
        let captures = [
            TreeSitterSyntaxCapture(byteRange: ByteRange(location: 24, length: 6), name: "string"),
            TreeSitterSyntaxCapture(byteRange: ByteRange(location: 32, length: 4), name: "number")
        ]

        XCTAssertEqual(TreeSitterSyntaxHighlightMapper.highlights(for: captures, localTo: request), [
            SyntaxHighlight(range: NSRange(location: 2, length: 3), name: "string"),
            SyntaxHighlight(range: NSRange(location: 6, length: 2), name: "number")
        ])
    }

    func testClipsMultilineCapturesAndDropsEmptyBoundaries() {
        let request = ByteRange(location: 20, length: 20)
        let captures = [
            TreeSitterSyntaxCapture(byteRange: ByteRange(location: 10, length: 16), name: "left"),
            TreeSitterSyntaxCapture(byteRange: ByteRange(location: 34, length: 12), name: "right"),
            TreeSitterSyntaxCapture(byteRange: ByteRange(location: 0, length: 20), name: "ends-at-start"),
            TreeSitterSyntaxCapture(byteRange: ByteRange(location: 40, length: 4), name: "starts-at-end")
        ]

        XCTAssertEqual(TreeSitterSyntaxHighlightMapper.highlights(for: captures, localTo: request), [
            SyntaxHighlight(range: NSRange(location: 0, length: 3), name: "left"),
            SyntaxHighlight(range: NSRange(location: 7, length: 3), name: "right")
        ])
    }

    func testPreservesCaptureOrderForNestedThemePrecedence() {
        let request = ByteRange(location: 0, length: 20)
        let captures = [
            TreeSitterSyntaxCapture(byteRange: request, name: "container"),
            TreeSitterSyntaxCapture(byteRange: ByteRange(location: 4, length: 8), name: "string.special")
        ]

        XCTAssertEqual(TreeSitterSyntaxHighlightMapper.highlights(for: captures, localTo: request).map(\.name), [
            "container", "string.special"
        ])
    }
}
