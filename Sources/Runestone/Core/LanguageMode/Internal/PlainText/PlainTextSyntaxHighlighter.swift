import Combine
import CoreGraphics
import Foundation

final class PlainTextSyntaxHighlighter: SyntaxHighlighter {
    let operationQueue: OperationQueue
    var inlinePredictionRange: NSRange?

    init(operationQueue: OperationQueue) {
        self.operationQueue = operationQueue
    }
}
