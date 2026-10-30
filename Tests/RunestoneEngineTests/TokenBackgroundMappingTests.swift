import Foundation
import RunestoneEngine
import XCTest

final class TokenBackgroundMappingTests: XCTestCase {
    func testBackgroundMappingPreservesInputAndAttributeRanges() {
        let background = NSAttributedString.Key("testBackground")
        let input = NSMutableAttributedString(string: "a😀bc")
        input.addAttribute(background, value: "first", range: NSRange(location: 1, length: 2))
        input.addAttribute(background, value: "second", range: NSRange(location: 4, length: 1))
        let result = TokenBackgroundMapping.stringForTypesetting(input, backgroundColorKey: background)

        XCTAssertEqual(result.string, input.string)
        XCTAssertNil(result.attribute(background, at: 1, effectiveRange: nil))
        XCTAssertEqual(result.attribute(TokenBackgroundMapping.attributeKey, at: 1, effectiveRange: nil) as? String, "first")
        XCTAssertNil(result.attribute(TokenBackgroundMapping.attributeKey, at: 3, effectiveRange: nil))
        XCTAssertEqual(result.attribute(TokenBackgroundMapping.attributeKey, at: 4, effectiveRange: nil) as? String, "second")
        XCTAssertEqual(input.attribute(background, at: 1, effectiveRange: nil) as? String, "first")
        XCTAssertNil(input.attribute(TokenBackgroundMapping.attributeKey, at: 1, effectiveRange: nil))
    }

    func testBackgroundMappingReturnsUnchangedInputWhenNoBackgroundExists() {
        let input = NSAttributedString(string: "plain")
        let background = NSAttributedString.Key("testBackground")
        XCTAssertTrue(TokenBackgroundMapping.stringForTypesetting(input, backgroundColorKey: background) === input)
        let empty = NSAttributedString(string: "")
        XCTAssertTrue(TokenBackgroundMapping.stringForTypesetting(empty, backgroundColorKey: background) === empty)
    }

}
