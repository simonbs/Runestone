import UIKit

final class IndexedRange: UITextRange {
    let range: NSRange
    override var start: UITextPosition {
        return IndexedPosition(index: range.location)
    }
    override var end: UITextPosition {
        return IndexedPosition(index: range.location + range.length)
    }
    override var isEmpty: Bool {
        return range.length == 0
    }

    init(_ range: NSRange) {
        self.range = range
    }

    convenience init(location: Int, length: Int) {
        let range = NSRange(location: location, length: length)
        self.init(range)
    }
}
