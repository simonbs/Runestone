#if os(macOS)
import AppKit

final class TextFinderClient: NSObject, NSTextFinderClient {
    weak var textView: TextView?

    var string: String {
        textView?.text ?? ""
    }

    var isEditable: Bool {
        true
    }

    func contentView(at index: Int, effectiveCharacterRange outRange: NSRangePointer) -> NSView {
        return textView!
    }
}
#endif
