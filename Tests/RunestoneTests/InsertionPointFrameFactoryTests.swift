@testable import Runestone
import XCTest

final class InsertionPointFrameFactoryTests: XCTestCase {
    func testVerticalBarFrameInFrontOfFirstCharacter() {
        let compositionRoot = CompositionRoot(preparingToDisplay: "Hello world!")
        compositionRoot.insertionPointShape.value = .verticalBar
        let insertionPointFrameFactory = compositionRoot.insertionPointFrameFactory
        let frame = insertionPointFrameFactory.frameOfInsertionPoint(at: 0)
        XCTAssertEqual(frame.minX, 0)
        XCTAssertEqual(frame.minY, 0)
        XCTAssertEqual(frame.width, 1)
        XCTAssertEqual(frame.height, 16.5, accuracy: 0.1)
    }

    func testVerticalBarFrameInFrontOfSecondCharacter() {
        let compositionRoot = CompositionRoot(preparingToDisplay: "Hello world!")
        compositionRoot.insertionPointShape.value = .verticalBar
        let insertionPointFrameFactory = compositionRoot.insertionPointFrameFactory
        let frame = insertionPointFrameFactory.frameOfInsertionPoint(at: 1)
        XCTAssertEqual(frame.minX, 8.7, accuracy: 0.1)
        XCTAssertEqual(frame.minY, 0)
        XCTAssertEqual(frame.width, 1)
        XCTAssertEqual(frame.height, 16.5, accuracy: 0.1)
    }

    func testVerticalBarFrameWidthRemainsFixedWhenPlacedInFrontOfLineBreak() {
        let compositionRoot = CompositionRoot(preparingToDisplay: "Hello world!\nHow are you?")
        compositionRoot.insertionPointShape.value = .verticalBar
        compositionRoot.estimatedCharacterWidth.rawValue.value = 42
        let insertionPointFrameFactory = compositionRoot.insertionPointFrameFactory
        let frame = insertionPointFrameFactory.frameOfInsertionPoint(at: 12)
        XCTAssertEqual(frame.minX, 103.9, accuracy: 0.1)
        XCTAssertEqual(frame.minY, 0)
        XCTAssertEqual(frame.width, 1)
        XCTAssertEqual(frame.height, 16.5, accuracy: 0.1)
    }

    func testUnderlineFrameInFrontOfFirstCharacter() {
        let compositionRoot = CompositionRoot(preparingToDisplay: "Hello world!")
        compositionRoot.insertionPointShape.value = .underline
        let insertionPointFrameFactory = compositionRoot.insertionPointFrameFactory
        let frame = insertionPointFrameFactory.frameOfInsertionPoint(at: 0)
        XCTAssertEqual(frame.minX, 0)
        XCTAssertEqual(frame.minY, 15.5, accuracy: 0.1)
        XCTAssertEqual(frame.width, 8.7, accuracy: 0.1)
        XCTAssertEqual(frame.height, 1)
    }

    func testUnderlineFrameInFrontOfSecondCharacter() {
        let compositionRoot = CompositionRoot(preparingToDisplay: "Hello world!")
        compositionRoot.insertionPointShape.value = .underline
        let insertionPointFrameFactory = compositionRoot.insertionPointFrameFactory
        let frame = insertionPointFrameFactory.frameOfInsertionPoint(at: 1)
        XCTAssertEqual(frame.minX, 8.7, accuracy: 0.1)
        XCTAssertEqual(frame.minY, 15.5, accuracy: 0.1)
        XCTAssertEqual(frame.width, 8.7, accuracy: 0.1)
        XCTAssertEqual(frame.height, 1)
    }

    func testUnderlineFrameWidthMatchesEstimatedCharacterWidthWhenPlacedInFrontOfLineBreak() {
        let compositionRoot = CompositionRoot(preparingToDisplay: "Hello world!\nHow are you?")
        compositionRoot.insertionPointShape.value = .underline
        compositionRoot.estimatedCharacterWidth.rawValue.value = 42
        let insertionPointFrameFactory = compositionRoot.insertionPointFrameFactory
        let frame = insertionPointFrameFactory.frameOfInsertionPoint(at: 12)
        XCTAssertEqual(frame.minX, 103.9, accuracy: 0.1)
        XCTAssertEqual(frame.minY, 15.5, accuracy: 0.1)
        XCTAssertEqual(frame.width, 42)
        XCTAssertEqual(frame.height, 1)
    }

    func testBlockFrameInFrontOfFirstCharacter() {
        let compositionRoot = CompositionRoot(preparingToDisplay: "Hello world!")
        compositionRoot.insertionPointShape.value = .block
        let insertionPointFrameFactory = compositionRoot.insertionPointFrameFactory
        let frame = insertionPointFrameFactory.frameOfInsertionPoint(at: 0)
        XCTAssertEqual(frame.minX, 0)
        XCTAssertEqual(frame.minY, 0)
        XCTAssertEqual(frame.width, 8.7, accuracy: 0.1)
        XCTAssertEqual(frame.height, 16.5, accuracy: 0.1)
    }

    func testBlockFrameInFrontOfSecondCharacter() {
        let compositionRoot = CompositionRoot(preparingToDisplay: "Hello world!")
        compositionRoot.insertionPointShape.value = .block
        let insertionPointFrameFactory = compositionRoot.insertionPointFrameFactory
        let frame = insertionPointFrameFactory.frameOfInsertionPoint(at: 1)
        XCTAssertEqual(frame.minX, 8.7, accuracy: 0.1)
        XCTAssertEqual(frame.minY, 0)
        XCTAssertEqual(frame.width, 8.7, accuracy: 0.1)
        XCTAssertEqual(frame.height, 16.5, accuracy: 0.1)
    }

    func testBlockFrameWidthMatchesEstimatedCharacterWidthWhenPlacedInFrontOfLineBreak() {
        let compositionRoot = CompositionRoot(preparingToDisplay: "Hello world!\nHow are you?")
        compositionRoot.insertionPointShape.value = .block
        compositionRoot.estimatedCharacterWidth.rawValue.value = 42
        let insertionPointFrameFactory = compositionRoot.insertionPointFrameFactory
        let frame = insertionPointFrameFactory.frameOfInsertionPoint(at: 12)
        XCTAssertEqual(frame.minX, 103.9, accuracy: 0.1)
        XCTAssertEqual(frame.minY, 0)
        XCTAssertEqual(frame.width, 42)
        XCTAssertEqual(frame.height, 16.5, accuracy: 0.1)
    }
}
