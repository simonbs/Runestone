@testable import Runestone
import XCTest

final class StringModifierTests: XCTestCase {
    func testNoModifiers() {
        let modifiedString = StringModifier.string(byApplying: [], to: "hello")
        XCTAssertEqual(modifiedString, "hello")
    }

    func testUppercaseLetterModifier() {
        let modifiedString = StringModifier.string(byApplying: [.uppercaseLetter], to: "hello")
        XCTAssertEqual(modifiedString, "Hello")
    }

    func testLowercaseLetterModifier() {
        let modifiedString = StringModifier.string(byApplying: [.lowercaseLetter], to: "HELLO")
        XCTAssertEqual(modifiedString, "hELLO")
    }

    func testUppercaseAllLettersModifier() {
        let modifiedString = StringModifier.string(byApplying: [.uppercaseAllLetters], to: "heLLo")
        XCTAssertEqual(modifiedString, "HELLO")
    }

    func testLowercaseAllLettersModifier() {
        let modifiedString = StringModifier.string(byApplying: [.lowercaseAllLetters], to: "HEllo")
        XCTAssertEqual(modifiedString, "hello")
    }

    func testUppercaseMultipleLettersModifiers() {
        let modifiedString = StringModifier.string(byApplying: [.uppercaseLetter, .uppercaseLetter], to: "hello")
        XCTAssertEqual(modifiedString, "HEllo")
    }

    func testLowercaseMultipleLettersModifiers() {
        let modifiedString = StringModifier.string(byApplying: [.lowercaseLetter, .lowercaseLetter], to: "HELLO")
        XCTAssertEqual(modifiedString, "heLLO")
    }

    func testMixLowercaseAndUppercaseModifiers() {
        let modifiedString = StringModifier.string(byApplying: [.lowercaseLetter, .uppercaseLetter], to: "Hello")
        XCTAssertEqual(modifiedString, "hEllo")
    }

    func testLowercaseTwoFirstCharactersAndUppercaseRestOfString() {
        let modifiedString = StringModifier.string(byApplying: [.lowercaseLetter, .lowercaseLetter, .uppercaseAllLetters], to: "HEllo")
        XCTAssertEqual(modifiedString, "heLLO")
    }

    func testTerminateModificationByUppercasingRestOfString() {
        let modifiedString = StringModifier.string(byApplying: [.lowercaseLetter, .uppercaseAllLetters, .lowercaseLetter], to: "HeLlo")
        XCTAssertEqual(modifiedString, "hELLO")
    }

    func testTerminateModificationByLowercasingRestOfString() {
        let modifiedString = StringModifier.string(byApplying: [.uppercaseLetter, .lowercaseAllLetters, .uppercaseLetter], to: "hElLO")
        XCTAssertEqual(modifiedString, "Hello")
    }

    func testIgnoreSecondModifierThatTerminatorsModification() {
        let modifiedString = StringModifier.string(byApplying: [.uppercaseLetter, .uppercaseAllLetters, .lowercaseAllLetters], to: "hello")
        XCTAssertEqual(modifiedString, "HELLO")
    }
}
