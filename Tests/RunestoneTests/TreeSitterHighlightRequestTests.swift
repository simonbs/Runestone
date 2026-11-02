@testable import Runestone
import TestTreeSitterLanguages
import XCTest

final class TreeSitterHighlightRequestTests: XCTestCase {
    func testCancellationReleasesAQueuedDocumentSnapshotBeforeWorkStarts() throws {
        let disposalQueue = OperationQueue()
        let disposer = TreeSitterHighlightResourceDisposer(queue: disposalQueue)
        weak var weakSnapshot: TreeSitterHighlightSnapshot?
        let request = try autoreleasepool {
            let snapshot = try makeSnapshot()
            weakSnapshot = snapshot
            return TreeSitterHighlightRequest(snapshot: snapshot, resourceDisposer: disposer)
        }
        XCTAssertNotNil(weakSnapshot)
        request.cancel()
        disposalQueue.waitUntilAllOperationsAreFinished()
        XCTAssertNil(weakSnapshot, "Canceling queued work must promptly release its document-sized snapshot.")
        XCTAssertNil(request.takeSnapshot())
    }

    func testCancellationReleasesCompletedCapturesBeforeMainThreadApplication() throws {
        let disposalQueue = OperationQueue()
        let disposer = TreeSitterHighlightResourceDisposer(queue: disposalQueue)
        weak var weakSnapshot: TreeSitterHighlightSnapshot?
        let request = try autoreleasepool {
            let snapshot = try makeSnapshot()
            weakSnapshot = snapshot
            let request = TreeSitterHighlightRequest(snapshot: snapshot, resourceDisposer: disposer)
            let workerSnapshot = try XCTUnwrap(request.takeSnapshot())
            let captures = workerSnapshot.captures(in: ByteRange(location: 0, length: 100))
            XCTAssertFalse(captures.isEmpty)
            request.complete(snapshot: workerSnapshot, captures: captures)
            return request
        }
        XCTAssertNotNil(weakSnapshot, "Completed captures must retain the trees backing their unsafe node references.")
        request.cancel()
        disposalQueue.waitUntilAllOperationsAreFinished()
        XCTAssertNil(weakSnapshot, "Canceled main-queue applications must not retain an obsolete full document.")
        XCTAssertNil(request.takeCompleted())
    }

    func testCancellationDuringQueryRejectsLateCompletionWithoutReleasingActiveWorkerSnapshot() throws {
        let disposalQueue = OperationQueue()
        let disposer = TreeSitterHighlightResourceDisposer(queue: disposalQueue)
        weak var weakSnapshot: TreeSitterHighlightSnapshot?
        let request = try autoreleasepool {
            let snapshot = try makeSnapshot()
            weakSnapshot = snapshot
            return TreeSitterHighlightRequest(snapshot: snapshot, resourceDisposer: disposer)
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

    func testCancellationRetainsAtMostOnePayloadWhileBackgroundDisposalIsBusy() throws {
        let disposalQueue = OperationQueue()
        disposalQueue.isSuspended = true
        defer {
            disposalQueue.isSuspended = false
            disposalQueue.waitUntilAllOperationsAreFinished()
        }
        let disposer = TreeSitterHighlightResourceDisposer(queue: disposalQueue)
        weak var firstSnapshot: TreeSitterHighlightSnapshot?
        let first = try autoreleasepool {
            let snapshot = try makeSnapshot()
            firstSnapshot = snapshot
            return TreeSitterHighlightRequest(snapshot: snapshot, resourceDisposer: disposer)
        }
        first.cancel()
        XCTAssertNotNil(firstSnapshot, "One canceled payload may await background destruction.")

        weak var secondSnapshot: TreeSitterHighlightSnapshot?
        let second = try autoreleasepool {
            let snapshot = try makeSnapshot()
            secondSnapshot = snapshot
            let request = TreeSitterHighlightRequest(snapshot: snapshot, resourceDisposer: disposer)
            let workerSnapshot = try XCTUnwrap(request.takeSnapshot())
            request.complete(snapshot: workerSnapshot, captures: workerSnapshot.captures(in: ByteRange(location: 0, length: 100)))
            return request
        }
        second.cancel()
        XCTAssertNil(secondSnapshot, "A busy disposer must release another completed payload synchronously.")
        XCTAssertNotNil(firstSnapshot)
        disposalQueue.isSuspended = false
        disposalQueue.waitUntilAllOperationsAreFinished()
        XCTAssertNil(firstSnapshot, "Background cleanup must release its payload without a main-queue callback.")
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
