import CoreText
import Foundation

struct ManagedLineFragment: LineFragment {
    let id: LineFragmentID = UUID()
    let index: Int = 0
    let location: Int = 0
    let length: Int = 0
    let visibleRange: NSRange = NSRange(location: 0, length: 0)
    let hiddenLength: Int = 0
    let descent: CGFloat = 0
    let baseSize: CGSize = .zero
    let scaledSize: CGSize = .zero
    let yPosition: CGFloat = 0
    var line: CTLine {
        fatalError()
    }
    
    func insertionPointRange(forLineLocalRange lineLocalRange: NSRange) -> NSRange? {
        nil
    }
}
