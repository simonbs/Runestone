@testable import Runestone
import TestTreeSitterLanguages
import XCTest

final class TreeSitterSyntaxHighlightProviderTests: XCTestCase {
    func testProducesSemanticHighlightsWithoutThemeResolution() {
        let context = makeContext(text: "let target = 42;")

        XCTAssertEqual(context.provider.highlights(in: context.range), [
            SyntaxHighlight(range: NSRange(location: 4, length: 6), name: "keyword"),
            SyntaxHighlight(range: NSRange(location: 13, length: 2), name: "number")
        ])
    }

    @MainActor
    func testQueuedRequestUsesCapturedParseGeneration() {
        let originalText = "let target = 42;"
        let context = makeContext(text: originalText)
        context.queue.isSuspended = true
        let completed = expectation(description: "Snapshot highlights returned")
        context.provider.highlights(in: context.range) { result, _ in
            XCTAssertEqual(try? result.get(), [
                SyntaxHighlight(range: NSRange(location: 4, length: 6), name: "keyword"),
                SyntaxHighlight(range: NSRange(location: 13, length: 2), name: "number")
            ])
            completed.fulfill()
        }
        context.stringView.string = "let ignored = false;" as NSString
        context.mode.parse(context.stringView.string)
        context.queue.isSuspended = false
        context.queue.waitUntilAllOperationsAreFinished()

        wait(for: [completed], timeout: 5)
    }

    @MainActor
    func testSupersededRequestCompletesAsCancelled() {
        let context = makeContext(text: "let target = 42;")
        context.queue.isSuspended = true
        let cancelled = expectation(description: "Superseded request cancelled")
        context.provider.highlights(in: context.range) { result, _ in
            guard case .failure = result else {
                XCTFail("Superseded request must not succeed")
                return
            }
            cancelled.fulfill()
        }
        let replacement = expectation(description: "Replacement request succeeds")
        context.provider.highlights(in: context.range) { result, _ in
            if case .failure(let error) = result {
                XCTFail("Replacement failed: \(error)")
            }
            replacement.fulfill()
        }
        context.queue.isSuspended = false
        context.queue.waitUntilAllOperationsAreFinished()

        wait(for: [cancelled, replacement], timeout: 5)
    }
}

private extension TreeSitterSyntaxHighlightProviderTests {
    struct Context {
        let provider: TreeSitterSyntaxHighlightProvider
        let mode: TreeSitterInternalLanguageMode
        let queue: OperationQueue
        let stringView: StringView
        let range: ByteRange
    }

    func makeContext(text: String) -> Context {
        let language = TreeSitterLanguage(tree_sitter_javascript(), highlightsQuery: .init(string: """
        ((identifier) @keyword (#eq? @keyword "target"))
        (number) @number
        """))
        let stringView = StringView(string: text)
        let lineManager = LineManager(stringView: stringView)
        lineManager.rebuild()
        let mode = TreeSitterInternalLanguageMode(language: language.internalLanguage, languageProvider: nil,
                                                  stringView: stringView, lineManager: lineManager)
        mode.parse(stringView.string)
        let queue = OperationQueue()
        let provider = TreeSitterSyntaxHighlightProvider(languageMode: mode, operationQueue: queue)
        let range = ByteRange(utf16Range: NSRange(location: 0, length: stringView.string.length))
        return Context(provider: provider, mode: mode, queue: queue, stringView: stringView, range: range)
    }
}
