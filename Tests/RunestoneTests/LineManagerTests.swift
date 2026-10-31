@testable import Runestone
import XCTest

final class LineManagerTests: XCTestCase {
    func testUnicodeLineByteRangesSurviveSplitJoinAndDeletion() {
        let stringView = StringView(string: "😀e\u{301}\tfirst\r\nאבגד second\n第三行\rfinal 😀\r\n")
        let manager = LineManager(stringView: stringView)
        manager.rebuild()
        let helper = TextEditHelper(stringView: stringView, lineManager: manager, lineEndings: .lf)
        assertLineIndex(manager, matches: stringView.string)

        func replace(_ range: NSRange, with text: String) {
            _ = helper.replaceText(in: range, with: text)
            assertLineIndex(manager, matches: stringView.string)
        }

        // Character insertion and a split within a Unicode line.
        replace(NSRange(location: 2, length: 0), with: "🐢")
        replace(NSRange(location: 4, length: 0), with: "\r\n")
        replace(NSRange(location: 4, length: 2), with: "")
        // Split an existing CRLF delimiter, then join it again.
        let crlf = stringView.string.range(of: "\r\n")
        replace(NSRange(location: crlf.location + 1, length: 0), with: "x")
        replace(NSRange(location: crlf.location + 1, length: 1), with: "")
        // Delete complete lines and replace a span across different delimiters.
        let secondLine = manager.line(atRow: 1)
        replace(NSRange(location: secondLine.location, length: secondLine.data.totalLength), with: "")
        replace(NSRange(location: 2, length: manager.line(atRow: 1).location), with: "新\n😀\r\n")
        replace(NSRange(location: stringView.string.length - 2, length: 2), with: "")
        replace(NSRange(location: stringView.string.length, length: 0), with: "\n")
        replace(NSRange(location: 0, length: stringView.string.length), with: "")
    }
}

private extension LineManagerTests {
    private struct ExpectedLine {
        let location: Int
        let length: Int
        let delimiter: Int
    }

    private func assertLineIndex(_ manager: LineManager, matches text: NSString,
                                 file: StaticString = #filePath, line: UInt = #line) {
        // Scan UTF-16 independently of LineManager and NewLineFinder. Byte
        // offsets are the parser's contract, including supplementary scalars.
        let units = Array((text as String).utf16)
        var expected: [ExpectedLine] = []
        var start = 0
        var index = 0
        while index < units.count {
            let unit = units[index]
            if unit == 10 || unit == 13 {
                let delimiter = unit == 13 && index + 1 < units.count && units[index + 1] == 10 ? 2 : 1
                expected.append(ExpectedLine(location: start, length: index + delimiter - start, delimiter: delimiter))
                index += delimiter
                start = index
            } else {
                index += 1
            }
        }
        expected.append(ExpectedLine(location: start, length: units.count - start, delimiter: 0))
        XCTAssertEqual(manager.lineCount, expected.count, file: file, line: line)
        guard manager.lineCount == expected.count else {
            return
        }
        for (row, entry) in expected.enumerated() {
            let node = manager.line(atRow: row)
            XCTAssertEqual(node.location, entry.location, file: file, line: line)
            XCTAssertEqual(node.data.totalLength, entry.length, file: file, line: line)
            XCTAssertEqual(node.data.delimiterLength, entry.delimiter, file: file, line: line)
            XCTAssertEqual(node.data.length, entry.length - entry.delimiter, file: file, line: line)
            XCTAssertEqual(node.data.startByte, ByteCount(utf16Length: entry.location), file: file, line: line)
            XCTAssertEqual(node.data.byteCount, ByteCount(utf16Length: entry.length), file: file, line: line)
            XCTAssertTrue(manager.line(containingByteAt: ByteCount(utf16Length: entry.location)) === node,
                          file: file, line: line)
        }
    }

    private func createLineManager(containing string: String) -> LineManager {
        let stringView = StringView(string: string)
        let lineManager = LineManager(stringView: stringView)
        lineManager.insert(string as NSString, at: 0)
        return lineManager
    }
}
