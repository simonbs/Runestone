#if canImport(AppKit)
import AppKit
import RunestoneEngine
@testable import RunestoneAppKit
import XCTest

final class AppKitLineTypesetterPreparationTests: XCTestCase {
    private let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    func testLongASCIIWordWrappingMatchesDefaultCoreTextPath() throws {
        let bodies = [
            String(repeating: "alpha beta gamma delta ", count: 220),
            String(repeating: "identifier09", count: 420),
            String(repeating: "value = 12345; next-value, ", count: 180),
            String(repeating: " ", count: 5_000),
            String(repeating: "a", count: 1_000) + " " + String(repeating: "b", count: 4_000)
        ]
        for ending in ["", "\n", "\r\n"] {
            for body in bodies {
                let text = NSMutableAttributedString(string: body + ending, attributes: attributes)
                text.addAttribute(.foregroundColor, value: NSColor.systemPurple,
                                  range: NSRange(location: 120, length: 80))
                let prepared = try XCTUnwrap(AppKitLineTypesetterPreparation().prepare(text))
                XCTAssertEqual(prepared.run.range, 0..<body.utf16.count)
                XCTAssertTrue(prepared.run.allowsInitialOffset)
                XCTAssertEqual(prepared.run.breakStrategy, .word)
                for width in [CGFloat(97.25), 320.25, 700] {
                    let actual = layout(text, width: width, preparation: AppKitLineTypesetterPreparation())
                    let expected = layout(text, width: width,
                                          preparation: DefaultLineTypesetterPreparation(backgroundColorKey: .backgroundColor))
                    assertEquivalent(actual, expected)
                }
            }
        }
    }

    func testMillionCharacterFixtureIsAdmittedByBoundedWordPath() throws {
        let body = String(repeating: "alpha beta gamma delta ", count: 47_663)
        let text = NSAttributedString(string: body, attributes: attributes)
        let prepared = try XCTUnwrap(AppKitLineTypesetterPreparation().prepare(text))
        XCTAssertEqual(prepared.run.range, 0..<text.length)
        XCTAssertEqual(prepared.run.breakStrategy, .word)
    }

    func testUnsupportedTextAndAttributesRetainDefaultPath() {
        let body = String(repeating: "alpha beta ", count: 400)
        let unsupportedStrings = [body + "é", body + "אבג", body + "👩‍💻", body + "\tvalue",
                                  body + "\0value", body + "\rvalue", body + "\nmore"]
        for string in unsupportedStrings {
            XCTAssertNil(AppKitLineTypesetterPreparation().prepare(NSAttributedString(string: string,
                                                                                       attributes: attributes)))
        }

        for (key, value) in [
            (NSAttributedString.Key.kern, NSNumber(value: 0.5)),
            (.ligature, NSNumber(value: 1)),
            (.paragraphStyle, NSMutableParagraphStyle())
        ] {
            let text = NSMutableAttributedString(string: body, attributes: attributes)
            text.addAttribute(key, value: value, range: NSRange(location: 0, length: text.length))
            XCTAssertNil(AppKitLineTypesetterPreparation().prepare(text))
        }
        XCTAssertNil(AppKitLineTypesetterPreparation().prepare(NSAttributedString(string: body)))
    }

    private var attributes: [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: NSColor.textColor]
    }

    private func layout(_ text: NSAttributedString, width: CGFloat,
                        preparation: LineTypesetterPreparation) -> [LineFragment] {
        let typesetter = LineTypesetter(lineID: UUID().uuidString, preparation: preparation)
        typesetter.constrainingWidth = width
        typesetter.prepareToTypeset(text)
        typesetter.typesetLineFragments(toLocation: text.length)
        return typesetter.lineFragments
    }

    private func assertEquivalent(_ actual: [LineFragment], _ expected: [LineFragment],
                                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.map(\.visibleRange), expected.map(\.visibleRange), file: file, line: line)
        XCTAssertEqual(actual.map(\.range), expected.map(\.range), file: file, line: line)
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for (actual, expected) in zip(actual, expected) {
            XCTAssertEqual(actual.baseSize.width, expected.baseSize.width, accuracy: 0.001, file: file, line: line)
            XCTAssertEqual(actual.baseSize.height, expected.baseSize.height, accuracy: 0.001, file: file, line: line)
            XCTAssertEqual(actual.yPosition, expected.yPosition, accuracy: 0.001, file: file, line: line)
        }
    }
}
#endif
