import _RunestoneStringUtilities
import Foundation

final class NSMutableAttributedStringView: StringView {
    var string: NSString {
        get {
            internalString.mutableString
        }
        set {
            internalString = NSMutableAttributedString(string: newValue as String)
        }
    }
    var attributedString: NSAttributedString {
        internalString
    }
    var byteCount: ByteCount {
        string.byteCount
    }

    private var internalString: NSMutableAttributedString

    init() {
        internalString = NSMutableAttributedString()
    }

    init(_ string: String) {
        internalString = NSMutableAttributedString(string: string)
    }

    func attributedSubstring(in range: NSRange) -> NSAttributedString? {
        guard range.location >= 0 && range.upperBound <= internalString.length else {
            return nil
        }
        return internalString.attributedSubstring(from: range)
    }

    func replaceText(in range: NSRange, with string: String) {
        internalString.replaceCharacters(in: range, with: string)
    }
}
