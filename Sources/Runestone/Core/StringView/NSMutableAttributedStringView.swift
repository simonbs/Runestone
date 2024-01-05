import _RunestoneStringUtilities
import Foundation

final class NSMutableAttributedStringView: StringView {
    var string: String {
        get {
            attributedString.string
        }
        set {
            internalString = NSMutableAttributedString(string: newValue)
        }
    }
    var attributedString: NSAttributedString {
        internalString
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

    func character(at location: Int) -> unichar {
        internalString.mutableString.character(at: location)
    }
}
