import _RunestoneStringUtilities
import Foundation

final class NSMutableStringView: StringView {
    var string: NSString {
        get {
            internalString
        }
        set {
            internalString = NSMutableString(string: newValue)
        }
    }

    var byteCount: ByteCount {
        string.byteCount
    }

    private var internalString: NSMutableString

    init(_ string: NSMutableString = NSMutableString()) {
        self.internalString = string
    }

    convenience init(_ string: String) {
        self.init(NSMutableString(string: string))
    }

    func substring(in range: NSRange) -> String? {
        if range.location >= 0 && range.upperBound <= internalString.length && range.length > 0 {
            return internalString.substring(with: range)
        } else {
            return nil
        }
    }

    func replaceText(in range: NSRange, with string: String) {
        internalString.replaceCharacters(in: range, with: string)
    }

    func bytes(in range: ByteRange) -> BytesView? {
        guard range.lowerBound.value >= 0 && range.upperBound <= string.byteCount else {
            return nil
        }
        var usedLength = 0
        guard let buffer = string.getBytes(
            in: NSRange(range),
            encoding: String.preferredUTF16Encoding,
            usedLength: &usedLength
        ) else {
            return nil
        }
        return BytesView(bytes: buffer, length: ByteCount(usedLength))
    }
}
