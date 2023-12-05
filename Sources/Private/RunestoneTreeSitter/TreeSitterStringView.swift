import _RunestoneStringUtilities
import Foundation

package protocol TreeSitterStringView {
    var byteCount: ByteCount { get }
    func substring(in range: NSRange) -> String?
    func bytes(in range: ByteRange) -> BytesView?
}
