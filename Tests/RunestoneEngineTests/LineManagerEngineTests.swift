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
            text.replaceText(in: range, with: replacement)
            let changes = manager.removeCharacters(in: range)
            changes.union(with: manager.insert(replacement as NSString, at: range.location))
            assertIndex()
            return changes
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
