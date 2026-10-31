import Foundation
import XCTest
@testable import RunestoneEngine

final class LineManagerEngineTests: XCTestCase {
    func testMixedUnicodeEditsPreserveLineIndexAndUnaffectedIdentity() {
        let text = StringView(string: "😀first\r\nאבגד\nthird\rlast\r\n")
        let manager = LineManager(stringView: text)
        manager.rebuild()
        let unaffected = manager.line(atRow: 2)

        func assertIndex(file: StaticString = #filePath, line: UInt = #line) {
            let units = Array((text.string as String).utf16)
            var expected: [(Int, Int, Int)] = []
            var start = 0
            var index = 0
            while index < units.count {
                if units[index] == 10 || units[index] == 13 {
                    let delimiter = units[index] == 13 && index + 1 < units.count && units[index + 1] == 10 ? 2 : 1
                    expected.append((start, index + delimiter - start, delimiter))
                    index += delimiter
                    start = index
                } else {
                    index += 1
                }
            }
            expected.append((start, units.count - start, 0))
            XCTAssertEqual(manager.lineCount, expected.count, file: file, line: line)
            guard manager.lineCount == expected.count else { return }
            for (row, entry) in expected.enumerated() {
                let node = manager.line(atRow: row)
                XCTAssertEqual(node.location, entry.0, file: file, line: line)
                XCTAssertEqual(node.data.totalLength, entry.1, file: file, line: line)
                XCTAssertEqual(node.data.delimiterLength, entry.2, file: file, line: line)
                XCTAssertEqual(node.data.startByte, ByteCount(utf16Length: entry.0), file: file, line: line)
                XCTAssertEqual(node.data.byteCount, ByteCount(utf16Length: entry.1), file: file, line: line)
                XCTAssertTrue(manager.line(containingByteAt: ByteCount(utf16Length: entry.0)) === node, file: file, line: line)
            }
        }
        @discardableResult
        func replace(_ range: NSRange, with replacement: String) -> LineChangeSet {
            let oldEnd = manager.linePosition(at: range.location + range.length)
            guard let edit = LineEditTransaction.replace(in: manager, range: range, with: replacement) else {
                XCTFail("Valid edit was rejected")
                return LineChangeSet()
            }
            XCTAssertEqual(edit.oldEndPosition, oldEnd)
            XCTAssertEqual(edit.startPosition, manager.linePosition(at: range.location))
            XCTAssertEqual(edit.newEndPosition, manager.linePosition(at: range.location + (replacement as NSString).length))
            assertIndex()
            return edit.lineChanges
        }

        assertIndex()
        let changes = replace(NSRange(location: 2, length: 0), with: "🐢")
        XCTAssertTrue(changes.editedLines.contains(manager.firstLine))
        XCTAssertTrue(manager.line(atRow: 2) === unaffected)
        let split = replace(NSRange(location: 4, length: 0), with: "\r\n")
        XCTAssertEqual(split.insertedLines.count, 1)
        guard let inserted = split.insertedLines.first else { return XCTFail("Expected the split line") }
        XCTAssertTrue(manager.line(atRow: 3) === unaffected)
        let join = replace(NSRange(location: 4, length: 2), with: "")
        XCTAssertTrue(join.removedLines.contains(inserted))
        XCTAssertTrue(manager.line(atRow: 2) === unaffected)
        let crlf = text.string.range(of: "\r\n")
        replace(NSRange(location: crlf.location + 1, length: 0), with: "x")
        replace(NSRange(location: crlf.location + 1, length: 1), with: "")
        replace(NSRange(location: 2, length: manager.line(atRow: 1).location), with: "新\n😀\r\n")
        replace(NSRange(location: 0, length: text.string.length), with: "")
    }

    func testTransactionReportsCrossLineUTF16Positions() throws {
        let text = StringView(string: "😀one\r\nnext\nend")
        let manager = LineManager(stringView: text)
        manager.rebuild()
        let result = try XCTUnwrap(LineEditTransaction.replace(in: manager, range: NSRange(location: 2, length: 7), with: "🐢\nZ"))
        XCTAssertEqual(result.oldEndPosition, LinePosition(row: 1, column: 2))
        XCTAssertEqual(result.startPosition, LinePosition(row: 0, column: 2))
        XCTAssertEqual(result.newEndPosition, LinePosition(row: 1, column: 1))
        XCTAssertEqual(text.string as String, "😀🐢\nZxt\nend")
        XCTAssertEqual(manager.lineCount, 3)
    }

    func testTransactionAcceptsInsertionAtEmptyAndTrailingPositions() throws {
        let text = StringView(string: "")
        let manager = LineManager(stringView: text)
        manager.rebuild()
        let insertion = try XCTUnwrap(LineEditTransaction.replace(in: manager, range: NSRange(location: 0, length: 0), with: "😀\n"))
        XCTAssertEqual(insertion.newEndPosition, LinePosition(row: 1, column: 0))
        let append = try XCTUnwrap(LineEditTransaction.replace(in: manager, range: NSRange(location: text.string.length, length: 0), with: "end"))
        XCTAssertEqual(append.startPosition, LinePosition(row: 1, column: 0))
        XCTAssertEqual(append.newEndPosition, LinePosition(row: 1, column: 3))
        XCTAssertEqual(text.string as String, "😀\nend")
    }

    func testInvalidTransactionDoesNotChangeTextOrLineIndex() {
        let text = StringView(string: "😀first\r\nsecond")
        let manager = LineManager(stringView: text)
        manager.rebuild()
        let first = manager.firstLine
        let last = manager.lastLine
        let original = text.string as String
        for range in [NSRange(location: NSNotFound, length: 1), NSRange(location: 0, length: Int.max),
                      NSRange(location: text.string.length + 1, length: 0)] {
            XCTAssertNil(LineEditTransaction.replace(in: manager, range: range, with: "changed"))
            XCTAssertEqual(text.string as String, original)
            XCTAssertEqual(manager.lineCount, 2)
            XCTAssertTrue(manager.firstLine === first)
            XCTAssertTrue(manager.lastLine === last)
        }
    }

    func testEditsAtLineBreakBoundariesMatchRebuiltIndex() throws {
        let cases: [(String, NSRange, String, String)] = [
            ("a\rb", NSRange(location: 2, length: 0), "\n", "a\r\nb"),
            ("a\nb", NSRange(location: 1, length: 0), "\r", "a\r\nb"),
            ("a\rX\nb", NSRange(location: 2, length: 1), "", "a\r\nb"),
            ("a\r\nb", NSRange(location: 2, length: 0), "X", "a\rX\nb"),
            ("a\r\nb", NSRange(location: 1, length: 1), "", "a\nb"),
            ("a\r\nb", NSRange(location: 2, length: 1), "", "a\rb"),
            ("a\r\nb", NSRange(location: 2, length: 0), "", "a\r\nb"),
            ("😀\rX\nlast", NSRange(location: 3, length: 1), "", "😀\r\nlast"),
            ("a\u{2028}b", NSRange(location: 1, length: 0), "x", "ax\u{2028}b"),
            ("a\u{2029}b", NSRange(location: 1, length: 0), "x", "ax\u{2029}b"),
            ("a\u{0085}b", NSRange(location: 1, length: 0), "x", "ax\u{0085}b"),
            ("a\u{000B}b", NSRange(location: 1, length: 0), "x", "ax\u{000B}b"),
            ("a\u{000C}b", NSRange(location: 1, length: 0), "x", "ax\u{000C}b")
        ]
        for (original, range, replacement, expected) in cases {
            let storage = StringView(string: original)
            let incremental = LineManager(stringView: storage)
            incremental.rebuild()
            XCTAssertNotNil(LineEditTransaction.replace(in: incremental, range: range, with: replacement), original.debugDescription)
            XCTAssertEqual(storage.string as String, expected)

            let rebuilt = LineManager(stringView: StringView(string: expected))
            rebuilt.rebuild()
            XCTAssertEqual(incremental.lineCount, rebuilt.lineCount, original.debugDescription)
            guard incremental.lineCount == rebuilt.lineCount else { continue }
            for row in 0..<rebuilt.lineCount {
                let actualLine = incremental.line(atRow: row)
                let expectedLine = rebuilt.line(atRow: row)
                XCTAssertEqual(actualLine.location, expectedLine.location, "row \(row) in \(original.debugDescription)")
                XCTAssertEqual(actualLine.data.totalLength, expectedLine.data.totalLength, "row \(row) in \(original.debugDescription)")
                XCTAssertEqual(actualLine.data.delimiterLength, expectedLine.data.delimiterLength, "row \(row) in \(original.debugDescription)")
            }
            for location in 0...storage.string.length {
                XCTAssertEqual(incremental.linePosition(at: location), rebuilt.linePosition(at: location),
                               "location \(location) in \(original.debugDescription)")
            }
        }
    }

    func testFoldedHeightAndHitTestingUseSharedLineGeometry() {
        let manager = LineManager(stringView: StringView(string: "a\nbb\nccc\ndddd"))
        manager.rebuild()
        let heights: [CGFloat] = [10, 20, 30, 40]
        for (row, height) in heights.enumerated() {
            manager.setHeight(of: manager.line(atRow: row), to: height)
        }
        let last = manager.line(atRow: 3)
        manager.setCollapsedLineRanges([1...2])
        XCTAssertEqual(manager.contentHeight, 50)
        XCTAssertEqual(last.yPosition, 10)
        XCTAssertTrue(manager.line(containingYOffset: 10) === last)
        XCTAssertTrue(manager.line(containingYOffset: 50) === last)
        XCTAssertTrue(manager.isLineHidden(1))
        XCTAssertTrue(manager.nextVisibleLine(after: manager.firstLine) === last)
    }
}
