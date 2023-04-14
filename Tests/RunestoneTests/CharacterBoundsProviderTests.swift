import Combine
@testable import Runestone
import XCTest

final class CharacterBoundsProviderTests: XCTestCase {
    func testGetBoundsOfFirstCharacter() {
        let compositionRoot = CompositionRoot(preparingToDisplay: "Hello world!")
        let characterBoundsProvider = compositionRoot.characterBoundsProvider
        guard let bounds = characterBoundsProvider.boundsOfCharacter(atLocation: 0, moveToToNextLineFragmentIfNeeded: false) else {
            XCTFail("Expected bounds but got nil")
            return
        }
        XCTAssertEqual(bounds.minX, 0)
        XCTAssertEqual(bounds.minY, 0)
        XCTAssertGreaterThan(bounds.width, 1)
        XCTAssertGreaterThan(bounds.height, 1)
    }

    func testGetBoundsOfSecondCharacter() {
        let compositionRoot = CompositionRoot(preparingToDisplay: "Hello world!")
        let characterBoundsProvider = compositionRoot.characterBoundsProvider
        guard let firstBounds = characterBoundsProvider.boundsOfCharacter(atLocation: 0, moveToToNextLineFragmentIfNeeded: false) else {
            XCTFail("Expected bounds but got nil")
            return
        }
        guard let secondBounds = characterBoundsProvider.boundsOfCharacter(atLocation: 1, moveToToNextLineFragmentIfNeeded: false) else {
            XCTFail("Expected bounds but got nil")
            return
        }
        XCTAssertNotEqual(secondBounds, firstBounds)
        XCTAssertGreaterThan(secondBounds.width, 1)
        XCTAssertGreaterThan(secondBounds.height, 1)
        XCTAssertGreaterThan(secondBounds.minX, 1)
        XCTAssertEqual(secondBounds.minY, 0)
    }

    func testGetBoundsOfLastCharacter() {
        let compositionRoot = CompositionRoot(preparingToDisplay: "Hello world!")
        let characterBoundsProvider = compositionRoot.characterBoundsProvider
        guard let bounds = characterBoundsProvider.boundsOfCharacter(atLocation: 11, moveToToNextLineFragmentIfNeeded: false) else {
            XCTFail("Expected bounds but got nil")
            return
        }
        XCTAssertGreaterThan(bounds.width, 1)
        XCTAssertGreaterThan(bounds.height, 1)
        XCTAssertEqual(bounds.minY, 0)
    }

    func testGetBoundsOfNonExistingCharacter() {
        let compositionRoot = CompositionRoot(preparingToDisplay: "Hello world!")
        let characterBoundsProvider = compositionRoot.characterBoundsProvider
        let bounds = characterBoundsProvider.boundsOfCharacter(atLocation: 12, moveToToNextLineFragmentIfNeeded: false)
        XCTAssertNil(bounds)
    }

    func testGetBoundsOfCharacterOnSecondLine() {
        let compositionRoot = CompositionRoot(preparingToDisplay: "Foo,\nBar")
        let characterBoundsProvider = compositionRoot.characterBoundsProvider
        guard let bounds = characterBoundsProvider.boundsOfCharacter(atLocation: 5, moveToToNextLineFragmentIfNeeded: false) else {
            XCTFail("Expected bounds but got nil")
            return
        }
        XCTAssertNotNil(bounds)
        XCTAssertGreaterThan(bounds.width, 1)
        XCTAssertGreaterThan(bounds.height, 1)
        XCTAssertGreaterThan(bounds.minY, 0)
    }
}
