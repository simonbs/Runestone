@testable import Runestone
import TestTreeSitterLanguages
import XCTest

final class TreeSitterHighlightRequestTests: XCTestCase {
    func testCancellationReleasesAQueuedDocumentSnapshotBeforeWorkStarts() throws {
        weak var weakSnapshot: TreeSitterHighlightSnapshot?
        let request = try autoreleasepool {
            let snapshot = try makeSnapshot()
            weakSnapshot = snapshot
            return TreeSitterHighlightRequest(snapshot: snapshot)
        }
        XCTAssertNotNil(weakSnapshot)
        request.cancel()
        XCTAssertNil(weakSnapshot, "Canceling queued work must promptly release its document-sized snapshot.")
        XCTAssertNil(request.takeSnapshot())
    }

    func testCancellationReleasesCompletedCapturesBeforeMainThreadApplication() throws {
        weak var weakSnapshot: TreeSitterHighlightSnapshot?
        let request = try autoreleasepool {
            let snapshot = try makeSnapshot()
            weakSnapshot = snapshot
            let request = TreeSitterHighlightRequest(snapshot: snapshot)
            let workerSnapshot = try XCTUnwrap(request.takeSnapshot())
            let captures = workerSnapshot.captures(in: ByteRange(location: 0, length: 100))
            XCTAssertFalse(captures.isEmpty)
            request.complete(snapshot: workerSnapshot, captures: captures)
            return request
        }
        XCTAssertNotNil(weakSnapshot, "Completed captures must retain the trees backing their unsafe node references.")
        request.cancel()
        XCTAssertNil(weakSnapshot, "Canceled main-queue applications must not retain an obsolete full document.")
        XCTAssertNil(request.takeCompleted())
    }

    func testCancellationDuringQueryRejectsLateCompletionWithoutReleasingActiveWorkerSnapshot() throws {
        weak var weakSnapshot: TreeSitterHighlightSnapshot?
        let request = try autoreleasepool {
            let snapshot = try makeSnapshot()
            weakSnapshot = snapshot
            return TreeSitterHighlightRequest(snapshot: snapshot)
        }
        try autoreleasepool {
            let workerSnapshot = try XCTUnwrap(request.takeSnapshot())
            request.cancel()
            let captures = workerSnapshot.captures(in: ByteRange(location: 0, length: 100))
            XCTAssertFalse(captures.isEmpty, "An executing query must keep its tree alive until it returns.")
            request.complete(snapshot: workerSnapshot, captures: captures)
            XCTAssertNil(request.takeCompleted(), "Cancellation must reject results published by an already-running worker.")
        }
        XCTAssertNil(weakSnapshot)
    }

    private func makeSnapshot() throws -> TreeSitterHighlightSnapshot {
        let parser = TreeSitterParser(encoding: .preferredUTF16)
        parser.language = tree_sitter_json()
        let text = "[1, 2, 3]"
        let tree = try XCTUnwrap(parser.parse(text as NSString))
        let query = try TreeSitterQuery(source: "(number) @number", language: tree_sitter_json())
        return TreeSitterHighlightSnapshot(layers: [.init(tree: tree, query: query)], stringView: StringView(string: text))
    }
}
