import _RunestoneStringUtilities
import _RunestoneTreeSitter
import Foundation

protocol StringView: AnyObject, TreeSitterStringView {
    var string: NSString { get set }
    func substring(in range: NSRange) -> String?
    func replaceText(in range: NSRange, with string: String)
    func bytes(in range: ByteRange) -> BytesView?
}

extension StringView {
    var length: Int {
        string.length
    }
}
